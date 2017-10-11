#!/bin/bash

# readonly REGEX_NAME='^[a-z]+[0-9]*((_|\-)[0-9]*[a-z]+[0-9]*)*$'

# Возвращает список дисков
getDiskList()
{
  echo $(fdisk -l 2>/dev/null | grep '^Disk /' | cut -f2 -d\ | sed 's/:$//') 2>/dev/null
}


# Возвращает полную информацию о диске
# $1 - имя устройства диска (/dev/sda)
getDiskInfoExt()
{
  local disk=$1
  fdisk -l $disk 2>/dev/null
}


# Возвращает краткую информацию о диске
# $1 - имя устройства диска (/dev/sda)
getDiskInfo()
{
  local disk=$1
  getDiskInfoExt $disk | head -n1 | sed 's/^Disk\ //' | tr ":" " "
}


# Возвращает информацию о (жестком) диске или значение одного из его свойств
# $1 - имя устройства диска (/dev/sda)
# $2 - название свойства | необязательный аргумент
# Список свойств:
#  - model (модель)
#  - dev (имя устройства)
#  - size (размер диска)
#  - ssl (Sector size logical)
#  - ssp (Sector size physical)
#  - pt (Partition Table)
#  - flags (Disk Flags)
#  - parts (список разделов)
getDiskInfoExt()
{
  local dev=$1
  local propName=$2
  if [[ (-n $dev) && (-b $dev) ]]; then
    local diskInfo=$(parted $dev print)
    if [[ -n $propName ]]; then
      :
    else
      echo $diskInfo
    fi
  fi
}


# Возвращает размер диска
# $1 - имя устройства диска (/dev/sda)
getDiskSize()
{
  local disk=$1
  fdisk -l $disk 2>/dev/null | head -n1 | cut -f3,4 -d\  | sed 's/,$//'
}


# Возвращает список дисков с их размером
# $1 - индикатор видивых пробелов, необходим для последующей обработки результата этой функции как массив (_)
getDiskListExt()
{
  if [[ $1 ]]; then
    fdisk -l 2>/dev/null | grep '^Disk /' | cut -f2,3,4 -d\ | sed 's/,$//' | tr " " "_"
  else
    fdisk -l 2>/dev/null | grep '^Disk /' | cut -f2,3,4 -d\ | sed 's/,$//'
  fi
}


# Возвращает список разделов диска
# $1 - имя устройства диска (/dev/sda)
getDiskPartList()
{
  local disk=$1
  fdisk -l $disk 2>/dev/null | grep ^$disk | tr "*" " " | sed -E 's/\ +/ /g' | cut -f1 -d\ 
}


# Возвращает список разделов всех дисков
getDiskPartAllList()
{
  fdisk -l 2>/dev/null | grep ^/dev/ | tr "*" " " | sed -E 's/\ +/ /g' | cut -f1 -d\ 
}


# Возвращает список разделов диска
# $1 - имя устройства диска (/dev/sda)
getDiskPartListExt()
{
  local disk=$1
  fdisk -l $disk 2>/dev/null | grep ^$disk | tr "*" " " | sed -E 's/\ +/ /g' | cut -f1,5,7 -d\ 
}


# Возвращает информацию о разделе диска
# $1 - имя устройства раздела диска (/dev/sda1)
getDiskPartInfo()
{
  local part=$1
  local disk=$(echo $part | sed -E 's/[0-9]+$//')
  getDiskPartListExt $disk | grep $part | tail -n1
}


# Возвращает одно или все значения свойств раздела диска
# $1 - имя устройства раздела диска (/dev/sda1)
# $2 - название свойства раздела диска | одно из (number start end size type fileSystem flags)| необязательно
getDiskPartInfoExt()
{
  local dev=$1
  local propName=$2
  local partNumber=$(echo $dev | sed -E 's/\/dev\/[a-z]+([1-9]+[a-z]+)*//')
  local disk=$(echo $dev | sed -E 's/[1-9]+[0-9]*$//')
  local -a partInfo=($(parted $disk print | grep ^\ $partNumber | sed -E 's/\s+/ /g; s/,\s/^/g; s/(^\ +)|(\ +$)//g'))
  # допустимые флаги раздела диска
  local -a partFlagList=(boot root swap hidden raid lvm lba legacy_boot irst esp palo)
  # если значение поля 'File system' (вывода команды parted dev_name print) пустое, 
  # оно могло принять значение следующего столбца
  # в таком случае переносим это значение в следующую колонку
  if [[ -n "$(arraySearch ${partInfo[5]} 'partFlagList')" ]]; then
    local newItem="${partInfo[6]}^${partInfo[5]}"
    newItem=$(echo $newItem | sed 's/^\^//')
    partInfo[5]='-'
    partInfo[6]=$newItem
  fi
  local -a partProps=(number start end size type fileSystem flags)
  if [[ -z $propName ]]; then
    echo ${partInfo[@]}
  else
    local propKey=$(arraySearch $propName 'partProps')
    if [[ -n $propKey ]]; then
      echo ${partInfo[$propKey]}
    fi
  fi
}


# Возвращает информацию о смонтированном устройстве (файле)
# $1 - имя устройства диска (/dev/sda)
getMountInfo()
{
  local dev=$1
  mount | grep ^"${dev} "
}


# Индикатор смонтированного устройства
# $1 - имя устройства диска (/dev/sda)
# зависит от функции getMountInfo()
isMounted()
{
  local dev=$1
  local mountInfo=$(getMountInfo $dev)
  if [[ -n $mountInfo ]]; then
    return 0
  else
    return 1
  fi
}


# Индикатор root-пользователя
isRoot()
{ 
  if [[ "$UID" == "0" ]] && [[ "$USER" == "root" ]]; then
    # true
    return 0
  else
    # false
    return 1
  fi
}


# Выводит значение переменной
# $1 - имя переменной (name)
# $2 - имя файла с номером строки вызова этой функции (file.sh:12)
varDump()
{
  local varName=$1
  local varValue=
  local varLocation=$2

  eval varValue='$'$varName
  echo "${varLocation} | \$${varName} = '${varValue}'"
}


# добавляет новый элемент в массив
# $1 - имя переменной массива ('array1')
# $2 - значение добавляемое в массив (100)
arrayPush()
{
  local arrayName=$1
  local itemValue=$2
  eval "$arrayName=(\"\${$arrayName[@]}\" $itemValue)"
}


# Возвращает 1-го массива с добавленными элементами в него 2-го
# $1 - имя переменной 1-го массива ('array1')
# $2 - имя переменной 2-го массива ('array2')
arrayMerge()
{
  local arrayName1=$1
  local arrayName2=$2
  eval "$arrayName1=(\${$arrayName1[@]} \${$arrayName2[@]})"
}


# Выводит список элементов массива
# $1 - имя переменной массива
arrayPrint()
{
  local arrayName=$1
  eval "echo \"\${$arrayName[@]}\" | tr \" \" \"\n\""
}


# Возвращает количество элементов массива
# $1 - имя переменной массива
arrayLength()
{
  local arrayName=$1
  eval "echo \${#$arrayName[@]}"
}


# Возвращает ключ первого найденного элемента в массиве
# $1 - искомое значение
# $2 - имя переменной массива
arraySearch()
{
  local value=$1
  local arrayName=$2

  if [[ (-n $value) && (-n $arrayName) ]]; then
    for (( i = 0; i < $(eval "echo \${#$arrayName[@]}"); i++ )); do
      if [[ $(eval "echo \${$arrayName[i]}") = $value ]]; then
        echo $i
        break
      fi
    done
  fi
}


# Индикатор числа с точкой
# $1 - проверяемое значение
isFloatNumber()
{
  local value=$1
  local regexFloatNumber='^[0-9]+.[0-9]+$'
  if [[ $value =~ $regexFloatNumber ]]; then
    return 0
  else
    return 1
  fi
}


local floatScale=2
# Вычислить выражение числа с плавающей запятой.
floatEval()
{
  # varDump 'floatScale' $0:$LINENO && return 0
  local stat=0
  local result=0.0
  if [[ $# -gt 0 ]]; then
    result=$(echo "scale=$floatScale; $*" | bc -q 2>/dev/null)
    stat=$?
    if [[ $stat -eq 0  &&  -z "$result" ]]; then stat=1; fi
  fi
  echo $result
  return $stat
}


# Вычислить условное выражение номера с плавающей запятой.
floatCond()
{
  local cond=0
  if [[ $# -gt 0 ]]; then
    cond=$(echo "$*" | bc -q 2>/dev/null)
    if [[ -z "$cond" ]]; then cond=0; fi
    if [[ "$cond" != 0  &&  "$cond" != 1 ]]; then cond=0; fi
  fi
  local stat=$((cond == 0))
  return $stat
}


# Преобразует значение размера в байты
# $1 - значение размера
# Зависит от функций:
#  arraySearch
conv2byte()
{
  local size=$(echo $1 | sed 's/,/./')
  local validSizeRegex='^((0?(,|.){1}0*[1-9]+)|([1-9]+[0-9]*))(K|M|G|T)?$'

  if [[ $size =~ $validSizeRegex ]]; then
    local sizeUnit=$(echo $size | sed -E 's/^((0?(,|.){1}0*[1-9]+)|([1-9]+[0-9]*))//')
    size=$(echo $size | sed -E 's/(K|M|G|T)$//')
    varDump 'size' $0:$LINENO
    varDump 'sizeUnit' $0:$LINENO

    if [[ -n $sizeUnit ]]; then
      local -a sizeUnitList=( K M G T )
      local sizeUnitKey=$(arraySearch $sizeUnit 'sizeUnitList')
      varDump 'sizeUnitKey' $0:$LINENO

      for (( i = 0; i < $((sizeUnitKey+1)); i++ )); do
        if isFloatNumber $size; then
          floatScale=0
          # ВНИМАИНЕ: Требует доработки! 
          # Не корректно умножаются числа с точкой
          size=$(floatEval "$size * 1024")
        else
          size=$((size*1024))
        fi
      done
    fi
    echo $size
  else
    echo 0
  fi
}


# Возврвщвет True, если $1 больше чем или равен $2
# $1 - значение размера 1
# $2 - значение размера 2
# Зависит от функций:
#  arraySearch
#  conv2byte
isVolumeSizeGreaterOrEqual()
{
  local volumeSize1=$1
  local volumeSize2=$2

  # еденицы измерений размера объема памяти
  local -a sizeUnitList=( K M G T )

  # ед.изм. размера 1-го значения
  local vs1unit=$(echo $volumeSize1 | sed -E 's/^[0-9]+//')
  vs1unit=$(arraySearch $vs1unit 'sizeUnitList')
  [ -z $vs1unit ] && vs1unit=0

  # ед.изм. размера 2-го значения
  local vs2unit=$(echo $volumeSize2 | sed -E 's/^[0-9]+//')
  vs2unit=$(arraySearch $vs2unit 'sizeUnitList')
  [ -z $vs2unit ] && vs2unit=0

  varDump 'vs1unit' $0:$LINENO
  varDump 'vs2unit' $0:$LINENO

  if [[ $vs1unit -lt $vs2unit ]]; then
    flag=False && varDump 'flag' $0:$LINENO
    return 1
  else
    # размер 1-го значения без ед.изм.
    local vs1size=$(echo $volumeSize1 | sed -E 's/(K|M|G|T)$//')
    # размер 2-го значения без ед.изм.
    local vs2size=$(echo $volumeSize2 | sed -E 's/(K|M|G|T)$//')

    varDump 'vs1size' $0:$LINENO
    varDump 'vs2size' $0:$LINENO

    if [[ $vs1size -ge $vs2size ]]; then
      # flag=True && varDump 'flag' $0:$LINENO
      return 0
    else
      # flag=False && varDump 'flag' $0:$LINENO
      return 1
    fi
  fi
}
