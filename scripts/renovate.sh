#!/bin/bash
set -o errexit

jq  '
        .tools as $tools |
        reduce (
            $tools[] | 
            select(.renovate != null) |
            select(.renovate.datasource | startswith("custom.")) |
            {
                "key":                        .renovate.datasource[7:],
                "defaultRegistryUrlTemplate": .renovate.datasourceUrl,
                "format":                     "json",
                "transformTemplates":         [ .renovate.datasourceTramsformJsonata ]
            }
        ) as $hash ([]; . + [$hash]) |
        [ .[] ] | map( 
            {
                (.key): {
                    "defaultRegistryUrlTemplate": .defaultRegistryUrlTemplate,
                    "format": .format,
                    "transformTemplates": .transformTemplates
                }
            }
        ) | add as $customDatasources |

        [
            $tools[] |
            if .renovate != null then
                {
                    "fileMatch": [ "^tools/" + .name + "/manifest.yaml$" ],
                    "matchStrings": [ "version: \"?(?<currentValue>.*?)\"?\\n" ],
                    "depNameTemplate": .renovate.package,
                    "datasourceTemplate": .renovate.datasource,
                    "packageNameTemplate": .renovate.url,
                    "registryUrlTemplate": .renovate.api,
                    "extractVersionTemplate": .renovate.extractVersion,
                    "versioningTemplate": .renovate.versioning
                }
                |
                if .packageNameTemplate == null then
                    del(.packageNameTemplate)
                else
                    .
                end
                |
                if .extractVersionTemplate == null then
                    del(.extractVersionTemplate)
                else
                    .
                end
                |
                if .versioningTemplate == null then
                    del(.versioningTemplate)
                else
                    .
                end
                |
                if .registryUrlTemplate == null then
                    del(.registryUrlTemplate)
                else
                    .
                end

            else
                empty
            end
        ] as $regexManagers |

        [
            $tools[] |
            if .renovate != null then
                if .renovate.allowPrereleases == true then
                    {
                        "matchFiles": [ "^tools/" + .name + "/manifest.yaml$" ],
                        "matchPackageNames": [ .renovate.package ],
                        "ignoreUnstable": (.renovate.allowPrereleases // false)
                    }

                else
                    empty
                end

            else
                empty
            end
        ] as $packageRules |

        {
            "customDatasources": $customDatasources,
            "packageRules": $packageRules,
            "regexManagers": $regexManagers
        }
    ' \
metadata.json \
| jq --slurp '.[0].regexManagers += .[1].regexManagers | .[0].packageRules += .[1].packageRules | .[0].customDatasources += .[1].customDatasources | .[0]' renovate-root.json - \
>renovate.json