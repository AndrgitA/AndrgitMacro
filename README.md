#  Аддон `AndrgitMacro`.
Предназначен для удобного использования спелами через макросы


##  `/andrgitmacro` или `/am` вызов команды макроса


`/am` - Показать инфо

`/am []` - Последовательные проверки через условие 'ИЛИ' (допустимо несколько условий). Внутри каждого такого условия можно перечислять через запятую условия, которые будут проверяться через условие 'И'

`/am [@player][@focus][@mouseover][@target][@mouseoverframe]` - **TARGET**. Обращение к таргету для проверки условий, обязательный параметр на 1 месте

`/am [TARGET,[help][harm][noharm][dead][deadorghost]...]` - Необязательные параметры идущие после параметра **TARGET**. Перечисление идет через запятую без пробелов.

Каждая из опций означает 
- `[help]` - проверка, что текущий таргет может быть ассистом для вас. кому вы можете дать хил, бафф или подобные дейсвтия
- `[harm]` - проверка, что текущий таргет является для вас враждебным
- `[noharm]` - проверка, что текущий таргет является для вас дружественным
- `[dead]` - проверка, что текущий таргет является мертвым
- `[deadorghost]` - проверка, что текущий таргет является мертвым или в форме духа");

- `[nobuff:BUFFNAME]` - проверка, что на игроке нет указанного баффа **BUFFNAME**
- `[buff:BUFFNAME]` - проверка, что на игроке есть указанный бафф **BUFFNAME**
- `[usableaction:slotID]` - проверка, что возможно нажать на **ActionBarSlotID**
- `[notusableaction:slotID]` - проверка, что нельзя нажать на **ActionBarSlotID**
- `[cd:SPELLNAME]` - проверка, что способность **SPELLNAME** на кулдауне
- `[nocd:SPELLNAME]` - проверка, что способность **SPELLNAME** не на кулдауне



```
Example
Если в таргете или курсор мыши наведен на unitframe, то кастуется Regrowth;
Если в таргете враг, то кастуется Starfire


/andrgitmacro [@mouseoverframe,help,noharm][@target,help,noharm] Regrowth;
/andrgitmacro [@target,harm] Starfire;
```

`/rl` - ReloadUI

`/amuseitem` - активировать item из 
```
Example
/amuseitem Hearthstone;
```
  
`/amcancelauras BUFF_NAME1[,BUFFNAME2]...` - Убрать ауру из баффов
```
Example
/amcancelauras Bear Form,Aquatic Form,Cat Form,Travel Form
```