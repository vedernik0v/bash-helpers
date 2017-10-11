#!/bin/bash

source ./common.sh

# Начинает работу LVM
lvm_begin()
{
  vgscan
  vgchange -ay
}

# Инициализация диска или раздела 
# $1 - имя устройства (/dev/sda[1])
lvm_pvCreate()
{
  local dev=$1
  local pvType
  local regexDisk='^/dev/[a-z]+$'
  local regexPart='^/dev/[a-z]+[1-9]+[0-9]*+$'

  if [[ $dev =~ $regexDisk ]] && [[ -b $dev ]]; then
    pvType='disk'
  elif [[ $dev =~ $regexPart ]] && [[ -b $dev ]]; then
    pvType='part'
  else
    echo "'$dev' is wrong!"
    return 1
  fi

  if (isMounted $dev); then
    :
  else
    pvcreate $dev
  fi
}

# Индикатор доступности группы томов
# $1 - название группы томов
lvm_isExistsVg()
{
  local vgName=$1
  if [[ -n $(vgscan | grep "Found volume group \"$vgName\"") ]]; then
    return 0
  else
    return 1
  fi
}

# Возвращает короткую информацию о групп[е|ах] томов
# $1 - название группы томов
lvm_getVgInfoShort()
{
  local vgName=$1
  vgdisplay -s $vgName 2>/dev/null | sed -E 's/^\s*//g;s/"//g;s/\s+/ /g'
}


# Возвращает список доступных групп томов
# Завистит от функции lvm_getVgInfoShort
lvm_getVgList()
{
  lvm_getVgInfoShort | cut -f1 -d\ 
}

# Индикатор допустимого названия логического тома
# $1 - строка
lvm_lvNameFilter()
{
  readonly REGEX_NAME='^[a-z]+[0-9]*((_|\-)[0-9]*[a-z]+[0-9]*)*$'
  local name=$1
  if [[ $name =~ $REGEX_NAME ]]; then
    return 0
  else
    return 1
  fi
}

# Индикатор существования логического тома
# $1 - название группы томов
# $2 - название логического тома
lvm_isExistsLv()
{
  local vgName=$1
  local lvName=$2

  if [[ -n $(lvscan -a | grep "$vgName/$lvName") ]]; then
    echo "Том '$lvName' присутствует в группе '$vgName'" >&2
    return 0
  else
    return 1
  fi
}

# Возвращает размер группы тома
# $1 - название группы тома (vg00)
lvm_getVgSize()
{
  local vgName=$1
  lvm_getVgInfoShort $vgName | cut -f2,3 -d\ 
}

# Возвращает размер свободного пространства группы тома
# $1 - название группы тома (vg00)
# Зависит от функции lvm_getVgInfoShort
lvm_getVgFreeSize()
{
  local vgName=$1
  lvm_getVgInfoShort $vgName | cut -f2 -d/ | sed 's/^\s*//g' | cut -f1,2 -d\ 
}

# Индикатор допустимого значения размера
# $1 - размер
isValidatedSize()
{
  local size=$1
  local REGEX='^0$|^[1-9]+[0-9]*(B|K|M|G)$'
  if [[ $size =~ $REGEX ]]; then
    return 0
  else
    return 1
  fi
}

# Индикатор доступности требуемой свободной памяти группы тома
# $1 - название группы тома (vg00)
# $2 - размер памяти (5G)
lvm_isAvailableVgFreeSize()
{
  local vgName=$1
  local vgFreeSize=$(lvm_getVgFreeSize $vgName | sed 's/.[0-9]*\ //;s/GiB/G/')
  # varDump 'vgFreeSize' $0:$LINENO
  local needSize=$2
  local flag=False
  # varDump 'needSize' $0:$LINENO
  if isValidatedSize $needSize; then
    :
    # flag=True && varDump 'flag' $0:$LINENO
  else
    # flag=False && varDump 'flag' $0:$LINENO
    echo "ОШИБКА: Недопустимое значение второго аргумента" >&2
    return 1
  fi

  if [[ -z $vgFreeSize ]] || [[ $vgFreeSize = 0 ]]; then
    # flag=False && varDump 'flag' $0:$LINENO
    return 1
  fi

  local -a sizeUnitList=( B K M G )

  # ед.изм. размера доступного места
  local asUnit=$(echo $vgFreeSize | sed -E 's/^[0-9]+//')
  asUnit=$(arraySearch $asUnit 'sizeUnitList')
  # varDump 'asUnit' $0:$LINENO
  # ед.изм. размера требуемого места
  local nsUnit=$(echo $needSize | sed -E 's/^[0-9]+//')
  nsUnit=$(arraySearch $nsUnit 'sizeUnitList')
  # varDump 'nsUnit' $0:$LINENO
  if [[ $asUnit -lt $nsUnit ]]; then
    # flag=False && varDump 'flag' $0:$LINENO
    return 1
  else
    # размер доступного места без ед.изм.
    local aSize=$(echo $vgFreeSize | sed -E 's/(B|K|M|G)$//')
    # varDump 'aSize' $0:$LINENO
    # размер требуемого места без ед.изм.
    local nSize=$(echo $needSize | sed -E 's/(B|K|M|G)$//')
    # varDump 'nSize' $0:$LINENO
    if [[ $aSize -ge $nSize ]]; then
      # flag=True && varDump 'flag' $0:$LINENO
      return 0
    else
      # flag=False && varDump 'flag' $0:$LINENO
      return 1
    fi
  fi
}

# Создает логический том
# $1 - название тома (если не указать, придется вводить)
# $2 - размер тома (из списка допустимых)
# $3 - название группы томов (из списка доступных)
# Зависит от функций:
#  arrayPush,
#  lvm_getVgFreeSize,
#  lvm_getVgList,
#  lvm_isAvailableVgFreeSize,
#  lvm_isExistsLv,
#  lvm_lvNameFilter
lvm_lvCreate()
{
  local vgName=$1
  local lvSize=$2
  local lvName=$3
  local -a sizeLvList=( 5G 10G 15G )
  local -a vgList=( $(lvm_getVgList) )
  local freeSize
  # declare -a vgList=(vg00 vg01)

  # если не найдено ниодной группы томов
  if [[ -z ${vgList[@]} ]]; then
    echo "Не найдено ниодной группы томов!"
    exit 1
  fi

  if [[ -z $vgName ]] || [[ -z ${vgList[$vgName]} ]]; then
    PS3="Выберите группу томов: "
    select vgName in ${vgList[@]}; do
      [[ -n "$vgName" ]] && break
    done
  fi
  freeSize=$(lvm_getVgFreeSize $vgName)
  # varDump 'freeSize' $0:$LINENO
  # echo "Группа томов: '$vgName'"

  echo "$0:$LINENO | sizeLvList = ($(arrayPrint 'sizeLvList')) | ${#sizeLvList[@]} | ${sizeLvList[-1]}"
  # Фильтрация списка предопределенных размеров согласно 
  # доступному свободному пространству группы томов
  local -a filteredSizeList=()
  for i in ${!sizeLvList[@]}; do
    if lvm_isAvailableVgFreeSize $vgName ${sizeLvList[$i]}; then
      arrayPush 'filteredSizeList' ${sizeLvList[$i]}
    else
      # unset sizeLvList
      break
    fi
  done
  echo "$0:$LINENO | filteredSizeList = ($(arrayPrint 'filteredSizeList')) | ${#filteredSizeList[@]}"


  if [[ ${#filteredSizeList[@]} -eq 0 ]] || (isVolumeSizeGreaterOrEqual $vgSize $freeSize); then
    echo "В группе томов '$vgName'[$freeSize] не хватает объема свободного пространства"
    echo " для добавления логического тома минимального разрешенного размера [${sizeLvList[0]}]!" >&2
    arrayPush 'filteredSizeList' $freeSize
  fi
  echo "$0:$LINENO | filteredSizeList = ($(arrayPrint 'filteredSizeList')) | ${#filteredSizeList[@]}"


  if [[ -z $lvSize ]] ; then
    if [[ ${#filteredSizeList[@]} -eq 1 ]]; then
      lvSize=${filteredSizeList[-1]}
    else
      PS3="Выберите размер тома: "
      select lvSize in ${filteredSizeList[@]}; do
        [[ -n "$lvSize" ]] && break
      done
    fi
  fi
  # echo "Размер тома: $lvSize"

  while [[ -z $lvName ]] || (!(lvm_lvNameFilter $lvName) && echo 'Недопустимое имя логического тома!' ) || (lvm_isExistsLv $vgName $lvName && echo 'Логический том с таким именем уже '); do
  # while [[ -z $lvName ]] || !(lvm_lvNameFilter $lvName) || !(lvm_isExistsLv $vgName $lvName); do
    read -p "Введите название тома: " lvName
  done
  # echo "Название тома: '$lvName'"

  echo "Вы действительно желаете создать новый логический том '${vgName}/${lvName}' размером '${lvSize}'? (y/N)"
  read $answer
  local regexYes='^(y|Y|yes|Yes)$'
  if [[ $4 =~ $regexYes ]] || [[ $answer =~ $regexYes ]]; then
    lvcreate -L$lvSize -n $lvName $vgName && \
    echo "Успешноо создан новый логический том '${vgName}/${lvName}' размером '${lvSize}"
  fi
}

# Завершает работу LVM
lvm_end()
{
  vgchange -an
}
