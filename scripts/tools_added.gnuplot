set terminal svg size 1920,1080
set output graphic_file_name
set grid
set datafile separator ","
set xdata time
set timefmt "%Y-%m"
set title "New tools per month"
set key box
set key right

# in the next three lines we are defining the style of the lines, where:
#
# lc - linecolor
# lt - linetype
# lw - linewidth
# pt - pointtype
# pt - pointinterval
# ps - pointsize
set style line 1 lc rgb '#4bd648' lt 1 lw 2 pt 7 pi -1 ps 1.5

plot csv_file_path using 1:2 title 'tools added' with linespoints ls 1
