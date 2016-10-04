#!/bin/bash

# Use this script for reporting from sqlite backed gnucash file.
# It takes all accounts that have child accounts of type MUTUAL (i.e. mutual funds) and
# generates line chart with three lines:
#  - Paid amount (how much money you put into the fund)
#  - Invested (how much money was actualy invested, i.e. paid - entry_fee)
#  - Current investment value
# From this chart, you can see how profitable the investment is as compared to its cost.
# The entry fee transactions have to have a memo 'Vstupní poplatek'
#
#DB_FILE=<path to gnucash file>
#TMP_DIR=<where to generate temporary data files>
#WWW_DIR=<where to store generated SVG file>

mkdir -p $TMP_DIR
mkdir -p $WWW_DIR

# list all accounts with (direct) subaccounts of type MUTUAL
sqlite3 $DB_FILE "SELECT base.guid, base.name FROM accounts AS base WHERE (SELECT COUNT(*) FROM accounts AS child WHERE child.account_type in ('MUTUAL') AND child.parent_guid = base.guid) > 0" | while read account_line; do
  # parse output from DB
  account_guid=$( echo $account_line | cut -d "|" -f 1 )
  account_name=$( echo $account_line | cut -d "|" -f 2 )
  file_name=$( echo $account_name | sed 's/ /_/g' )
  data_file="$TMP_DIR/$file_name.dat"
  graph_file="$WWW_DIR/$file_name.svg"
  
  # find out the first mont there was a transaction on the account
  account_start=$( sqlite3 $DB_FILE "SELECT MIN(tx.post_date) FROM splits INNER JOIN transactions AS tx on splits.tx_guid = tx.guid WHERE splits.account_guid = '$account_guid'" | sed -r "s/([0-9]{4})([0-9]{2})([0-9]{2}).*/\1-\2-01/g" )

  # print header
  echo
  echo "Account: $account_name (id: $account_guid)"
  echo "Report start date: $account_start"
  echo

  # create monthly report
  date=$account_start
  printf "%10s %12s %12s %12s %12s\n" "DATE" "TOTAL" "ENTRY FEE" "VALUE" "INVESTED"
  printf "%10s %12s %12s %12s %12s\n" "DATE" "TOTAL" "ENTRY FEE" "VALUE" "INVESTED" > $data_file
  while [[ "$date" < $( date -I ) ]]; do
    db_date=$( date -d $date +%Y%m%d )

    # count total invested amount
    total=$( sqlite3 $DB_FILE "SELECT SUM(base.value_num * 1.0 / base.value_denom) AS total FROM splits AS base INNER JOIN transactions AS tx ON base.tx_guid = tx.guid WHERE base.account_guid='$account_guid' AND base.value_num > 0 AND tx.post_date < '$db_date'" )

    # count entry fee paid so far
    entry_fee=$( sqlite3 $DB_FILE "SELECT ABS(SUM(base.value_num * 1.00 / base.value_denom)) AS total FROM splits AS base INNER JOIN transactions AS tx ON base.tx_guid = tx.guid WHERE account_guid='$account_guid' AND tx.description = 'Vstupní poplatek' AND tx.post_date < '$db_date'")
    if [[ -z "$entry_fee" ]]; then
      entry_fee=0
    fi

    # count current value of all subaccounts
    current_value=0
    subaccounts=$( sqlite3 $DB_FILE "SELECT guid,commodity_guid FROM accounts WHERE account_type = 'MUTUAL' AND parent_guid='$account_guid'" )
    for subaccount_line in $subaccounts; do
      subaccount=$( echo $subaccount_line | cut -d "|" -f 1 )
      commodity=$( echo $subaccount_line | cut -d "|" -f 2 )

      price=$( sqlite3 $DB_FILE "SELECT value_num * 1.00 / value_denom FROM prices WHERE commodity_guid = '$commodity' AND date = (SELECT MAX(date) FROM prices WHERE commodity_guid = '$commodity' AND date < '$db_date')" )
      balance=$( sqlite3 $DB_FILE "SELECT SUM(quantity_num * 1.0 / quantity_denom) FROM splits INNER JOIN transactions AS tx ON tx_guid = tx.guid WHERE account_guid='$subaccount' AND tx.post_date < '$db_date'" )

      current_value=$( echo "scale=2;$price * $balance + $current_value" | bc )
    done

    # count invested value
    invested=$( echo "scale=2;$total - $entry_fee" | bc )

    # print all the information
    printf "%10s %12.2f %12.2f %12.2f %12.2f\n" $date $total $entry_fee $current_value $invested
    printf "%10s %12.2f %12.2f %12.2f %12.2f\n" $date $total $entry_fee $current_value $invested >> $data_file

    date=$( date -I -d "$date + 1 month" )
  done

  gnuplot <<CLI
reset

set terminal svg enhanced size 2000,800 linewidth 1 background rgb 'white'
set output '$graph_file'

set xdata time
set timefmt "%Y-%m-%d"
set format x "%Y-%m-%d"
set xlabel 'Datum'

set ylabel 'Hodnota'

set key reverse Left outside

set grid
set style data linespoints

plot '$data_file'\
   using 1:2 title 'Zaplaceno'   pt 6 ps 1,\
'' using 1:4 title 'Hodnota'     pt 7 ps 1,\
'' using 1:5 title 'Investováno' pt 6 ps 1

CLI

  echo
done

