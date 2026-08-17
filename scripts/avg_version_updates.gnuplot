myTextColor = '#4bd648'
myLineColor = myTextColor

set title "Average version updates per tool and month" textcolor rgb myTextColor

set xlabel "Month" textcolor rgb myTextColor
set xdata time
set timefmt "%Y-%m"
set xtics textcolor rgb myTextColor
set format x "%Y-%m-%d"
set ylabel "Average number of version updates per tool" textcolor rgb myTextColor
set ytics textcolor rgb myTextColor

set terminal svg size 1920,1080 font ",24"
set output graphic_file_name
set datafile separator ","
set key off

set style line 1 \
    linecolor rgb myLineColor \
    linetype 1 \
    linewidth 2 \
    pointtype 7 \
    pointsize 1.5

plot csv_file_path using 1:5 with linespoints ls 1
