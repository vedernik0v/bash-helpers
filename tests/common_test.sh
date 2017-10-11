#!/bin/bash

source '../common.sh'

function test__isFloatNumber()
{
  local _fn='isFloatNumber'

  echo "$0:$LINENO | $_fn"
  isFloatNumber && echo 'True' || echo 'False'
  echo
  echo "$0:$LINENO | $_fn 1.0"
  (isFloatNumber 1.0) && echo 'True' || echo 'False'
  echo
}

function test__isVolumeSizeGreaterOrEqual()
{
  local _fn='isVolumeSizeGreaterOrEqual'

  echo "$0:$LINENO | $_fn 1 10"
  if (isVolumeSizeGreaterOrEqual 1 10); then echo 'True'; else echo 'False'; fi
  echo
  exit
  echo "$0:$LINENO | $_fn 0 1"
  if (isVolumeSizeGreaterOrEqual 0 1); then echo 'True'; else echo 'False'; fi
  echo
  echo "$0:$LINENO | $_fn 0"
  if (isVolumeSizeGreaterOrEqual 0); then echo 'True'; else echo 'False'; fi
  echo
  echo "$0:$LINENO | $_fn"
  if (isVolumeSizeGreaterOrEqual); then echo 'True'; else echo 'False'; fi
}

function test__conv2byte()
{
  local _fn='conv2byte'

  echo "$0:$LINENO | $_fn 1"
  conv2byte 1
  echo

  echo "$0:$LINENO | $_fn 1K"
  conv2byte 1K
  echo

  echo "$0:$LINENO | $_fn 1M"
  conv2byte 1M
  echo

  echo "$0:$LINENO | $_fn 10M"
  conv2byte 10M
  echo

  echo "$0:$LINENO | $_fn 0,2K"
  conv2byte 0,2K
  echo

  echo "$0:$LINENO | $_fn 0.5K"
  conv2byte 0.5K
  echo

  echo "$0:$LINENO | $_fn 1"
  conv2byte 1
  echo

  echo "$0:$LINENO | $_fn 0"
  conv2byte 0
}

function test__regexVolumeSize()
{ 
  local _fn='regexVolumeSize'

  local validSizeRegex='^((0?(,|.){1}0*[1-9]+)|([1-9]+[0-9]*))(K|M|G|T)?$'

  local size='0'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo

  local size='1'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo

  local size='.1'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo

  local size=',1'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo

  local size='0.1'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo

  local size='0,1'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo

  local size='0.01'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo

  local size='0,1.'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo

  local size='0,.01'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo

  local size='0..01'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo

  local size='0..01'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo

  local size='0.01K'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo

  local size='001K'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo

  local size='.001K'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo

  local size=',001K'
  echo "$0:$LINENO | $_fn $size"
  [[ $size =~ $validSizeRegex ]] && echo 'True' || echo 'False'
  echo
}

# Выбор тестируемой функции
function main()
{
  declare -a  functionList=(
                conv2byte
                isFloatNumber
                isVolumeSizeGreaterOrEqual
                regexVolumeSize
              )

  # arrayPrint 'functionList'
  PS3="Выберите функцию: "
  select fName in ${functionList[@]}; do
    [[ -n "$fName" ]] && break
  done
  # varDump 'fName' $0:$LINENO
  eval "test__$fName"
}

scriptFileName=${0##*/}
[ "${scriptFileName}" == "test-helpers.sh" ] && main
