#!/bin/bash

print_help() {
  echo "Usage: $0 FILE ACCOUNT"
  echo "Input file must be CSV with one header line and five columns as follows: Security name, date, price, quantity, total cost delimited by comma."
  exit 1
}

input_file=""
if [[ $# -lt 2 ]]; then
  print_help
fi

if [[ -z "$1" ]]; then
  print_help
else
  input_file=$1
fi

root_account=""
if [[ -z "$2" ]]; then
  print_help
else
  root_account=$2
fi

echo "!Account"
echo "N$root_account"
echo "^"

row_number=0
for line in $( cat $input_file ); do
  row_number=$(( $row_number + 1 ))
  if [[ $row_number -eq 1 ]]; then
    continue;
  fi

  echo "!Type:Invst"
  echo "PInvestice"
  echo "NBuyX"
  echo "L[$root_account]"
  echo "D$( echo $line | cut -d "," -f 2 )"
  echo "Y$( echo $line | cut -d "," -f 1 )"
  echo "Q$( echo $line | cut -d "," -f 4 )"
  echo "T$( echo $line | cut -d "," -f 5 )"
  echo "^"

done
