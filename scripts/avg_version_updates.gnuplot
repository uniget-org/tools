myTextColor = '#4bd648'
myLineColor = myTextColor

set title "Average version updates per tool and month" textcolor rgb myTextColor

set xlabel "Month" textcolor rgb myTextColor
set xdata time
set timefmt "%Y-%m"
set xtics format "%Y" textcolor rgb myTextColor
set ylabel "Average version updates" textcolor rgb myTextColor
set ytics textcolor rgb myTextColor

set terminal svg size 1920,1080 font ",24"
set output graphic_file_name
set grid
set datafile separator ","
set key box
set key right

set style line 1 lc rgb myLineColor lt 1 lw 2 pt 7 pi -1 ps 1.5

plot csv_file_path using 1:5 with linespoints ls 1
