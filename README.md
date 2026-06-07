# Руководство по структуре проекта Campfire (Godot 4)

Добро пожаловать в проект **Campfire**! Этот документ создан для того, чтобы помочь вам легко ориентироваться в папках проекта, понимать, где находятся игровые объекты и какой код отвечает за поведение каждого предмета.

---

## 📁 Главные папки проекта

* **`assets/`** — Графические ресурсы, текстуры и шейдеры.
  * **`assets/textures/`** — Все пиксель-арт спрайты (`.png`). Если вы хотите заменить картинку предмета, достаточно заменить файл в этой папке с тем же именем.
  * **`assets/shaders/`** — Шейдеры (например, `wind_sway.gdshader` для покачивания крон деревьев от ветра).
* **`scenes/`** — Самая важная папка. Здесь лежат все игровые сцены (`.tscn`) и привязанные к ним скрипты кода (`.gd`). Каждая папка внутри отвечает за конкретный предмет или юнит.

---

## 🔍 Какой код за что отвечает?

Ниже приведена карта всех сцен и скриптов в папке `scenes/`:

### 1. Ядро игры (Главные сцены)
* 🗺️ **`scenes/main/`**
  * [main.tscn](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/main/main.tscn) — Главная сцена мира. Содержит расстановку земли, домов, костра и деревьев.
  * [main.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/main/main.gd) — Контроллер игрового процесса. Управляет сменой дня и ночи, спавном бродяг и ночных волков/медведей, а также обрабатывает Game Over, если костер потухнет.

### 2. Главный герой
* 👑 **`scenes/player/`**
  * [player.tscn](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/player/player.tscn) — Физическое тело игрока (Короля), камера со сглаживанием и факел.
  * [player.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/player/player.gd) — Логика управления: ходьба, прыжки, сбор дров, отображение стопки дров над головой и взаимодействие с объектами по клавише **`E`**. Также отвечает за тряску камеры (Screen Shake).

### 3. Здания и постройки
* 🏠 **`scenes/buildings/`**
  * [lumberjack_house.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/buildings/lumberjack_house.gd) — **Дом лесоруба**. Управляет наймом лесорубов и визуальным отображением склада дров (максимум 20 штук).
  * [barracks.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/buildings/barracks.gd) — **Казарма**. Отвечает за найм копейщиков.
  * [builder_house.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/buildings/builder_house.gd) — **Дом строителя**. Отвечает за найм строителей.
  * [wall.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/buildings/wall.gd) — **Оборонительная стена**. Управляет постройкой, прочностью (HP), починкой и улучшениями (Уровень 1: Дерево -> Уровень 2: Камень -> Уровень 3: Шипы, наносящие ответный урон волкам).
  * [archer_tower.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/buildings/archer_tower.gd) — **Башня лучников**. Сканирует область вокруг себя и стреляет стрелами во врагов раз в 1.5 секунды.
  * [arrow.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/buildings/arrow.gd) — **Стрела (снаряд)**. Управляет физическим полетом стрелы по баллистической дуге в сторону цели и нанесением урона при попадании.

### 4. Юниты (Жители вашего поселения)
* 👷 **`scenes/units/`**
  * [builder.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/units/builder.gd) — **Строитель**. Его ИИ автоматически ищет недостроенные стены/башни, идет за деревом на землю или на склад, приносит его к стройке и строит здания.
  * [lumberjack.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/units/lumberjack.gd) — **Лесоруб**. Его ИИ ищет ближайшие деревья, рубит их с повышенным уроном, собирает выпавшие дрова и относит на склад.
  * [spearman.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/units/spearman.gd) — **Копейщик**. Распределяется на левый или правый фланг, встает на пост перед стеной и защищает базу от волков копьем.
* 💤 **`scenes/vagrant/`**
  * [vagrant.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/vagrant/vagrant.gd) — **Бродяга**. Бегает вокруг костра. Игрок может нанять его за 1 дерево, после чего бродяга становится свободным гражданином (`citizen`) и следует за игроком, готовый принять любую профессию.

### 5. Окружение и Ресурсы
* 🔥 **`scenes/campfire/`**
  * [campfire.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/campfire/campfire.gd) — **Костер**. Отвечает за уровень топлива, медленное затухание пламени и мерцание освещения.
* 🌲 **`scenes/tree/`**
  * [tree.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/tree/tree.gd) — **Дерево**. Реализует прочность дерева, анимацию падения, спавн дров при вырубке и таймер регенерации (новое дерево вырастает через 3 минуты).
* 🪵 **`scenes/wood/`**
  * [wood.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/wood/wood.gd) — **Дрова (полено)**. Управляет красивым разлетом дров при падении и их автоматическим притяжением (магнетизмом) к игроку, лесорубу или строителю.

### 6. Враги (Монстры)
* 🐺 **`scenes/enemy/`**
  * [enemy.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/enemy/enemy.gd) — **Волк**. Базовый враг, бежит ночью из пещеры к костру, кусает стены и защитников.
  * [bear.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/enemy/bear.gd) — **Медведь**. Сильный враг с большим запасом здоровья (80 HP) и высоким уроном по стенам (24 HP). Появляется начиная с 3-й ночи.

### 7. Системные файлы
* ⚙️ [texture_loader.gd](file:///Users/aydarbekovabdujamil1406gmail.com/Desktop/Game%20Jam/scenes/texture_loader.gd) — Скрипт-утилита. Если в папке `assets/textures/` лежит нужный спрайт, этот код автоматически заменяет им простую векторную графику объекта в игре, настраивая размеры и сдвиги.

---

## 🛠️ Как это устроено в редакторе Godot

Все объекты в Godot состоят из **Узлов (Nodes)**. Для каждого объекта в `.tscn` вы найдете:
1. **`CollisionShape2D`** — определяет физические границы объекта (чтобы персонажи стояли на земле и не проваливались).
2. **`VisualBuilt`** (или **`Body`** / **`Visual`**) — это векторное отображение объекта (сделано из разноцветных прямоугольников и линий на случай, если текстура не загрузится).
3. **`LabelStatus`** — текстовая плашка над объектом, которая загорается, когда вы подходите близко (подсказка клавиши взаимодействия `[E]`).
