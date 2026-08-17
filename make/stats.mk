PLOTS := $(shell find scripts -name '*.gnuplot' | cut -d/ -f2-)

stats/tools_added.json:
	@\
	mkdir -p stats; \
	cat metadata-full.json \
	| jq '[ .tools[] | { "name": .name, "added": .history[-1].date | strptime("%a %b %d %H:%M:%S %Y %z") | mktime } ]' \
	| jq '[ .[] | . + {"added_month": (.added | strftime("%Y-%m"))} ]' \
	| jq 'group_by(.added_month) | map({ "\(.[0].added_month)": { tools_added: length } }) | add' \
	>$@

stats/version_updates.json:
	@\
	mkdir -p stats; \
	cat history.json \
	| jq '[ .[] | select(.message | startswith("chore(deps): ")) | .date | strptime("%a %b %d %H:%M:%S %Y %z") | mktime ]' \
	| jq 'group_by(. | strftime("%Y-%m")) | map({ "\(.[0] | strftime("%Y-%m"))": { version_updates: length } }) | add' \
	>$@

stats/merged.json: stats/tools_added.json stats/version_updates.json
	@\
	jq -s '.[0] * .[1] | to_entries | map(.month = .key | del(.key) | . + .value | del(.value))' stats/tools_added.json stats/version_updates.json \
	| jq 'reduce .[] as $$item ({sum:0, out:[]}; .sum += $$item.tools_added | .out += [ $$item + {tool_count:.sum} ]) | .out' \
	| jq 'map(. + {avg_version_updates: (if (.tool_count // 0) == 0 then null else (.version_updates // 0) / .tool_count end)})' \
	>$@

stats/updates_per_tool.json:
	@\
	mkdir -p stats; \
	cat history.json \
	| jq 'map(select(.message | startswith("chore(deps): "))) | map(select(.tools | length == 1))' \
	| jq 'group_by(.tools[0]) | map({ tool: .[0].tools[0], updates: length, dates: (. | map(.date | strptime("%a %b %d %H:%M:%S %Y %z") | mktime)) })' \
	>$@

stats/updates_per_tool_histogram.json: stats/updates_per_tool.json
	@\
	cat stats/updates_per_tool.json \
	| jq 'map({ tool, updates }) | sort_by(.updates)' \
	>$@

stats/%.csv: stats/%.json
	@jq -r '.[] | to_entries | map(.value) | @csv' stats/$*.json >stats/$*.csv

$(PLOTS:%.gnuplot=stats/%.svg):stats/%.svg: stats/merged.csv scripts/%.gnuplot
	@gnuplot -e "csv_file_path='stats/merged.csv'" -e "graphic_file_name='$@'" scripts/$*.gnuplot

stats/updates_per_tool_histogram.svg:stats/%.svg: stats/updates_per_tool_histogram.csv scripts/%.gnuplot
	@gnuplot -e "csv_file_path='stats/$*.csv'" -e "graphic_file_name='$@'" scripts/$*.gnuplot
