asim +access +r work.top
run -all
acdb save -file fcover.acdb
acdb report -db fcover.acdb -o fcover.txt
exec cat fcover.txt
quit