myTextColor = '#4bd648'
myLineColor = myTextColor

set title "Version updates per tool and month" textcolor rgb myTextColor

set xlabel "Number of updates" textcolor rgb myTextColor
set xtics autofreq textcolor rgb myTextColor
set ylabel "Number of tools" textcolor rgb myTextColor
set ytics textcolor rgb myTextColor

set terminal svg size 1920,1080 font ",24"
set output graphic_file_name
set datafile separator ","
set key off

set style data histogram
set style histogram clustered gap 1
set style fill solid border -1
set boxwidth 10

plot csv_file_path using 2
