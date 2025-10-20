# 🎮 FPGA Doodle Jump

This project is the final report for the CS2104 Hardware Design Lab, detailing the implementation of a classic Doodle Jump game on an **Xilinx Artix-7 FPGA board**. The game features real-time control, a dynamically scrolling background, sound effects, and custom logic to simulate physics like bouncing and gravity.

## 💻 Technologies and Hardware

This project was developed using a hardware description language for implementation on the following physical components:

* **FPGA Board**
* **Keyboard** (PS/2) for character control
* **VGA Display** for graphics
* **Pmod Audio Amplifier** for sound
* **Seven-Segment Display** for in-game information (current height/game state)

[cite_start]The game's logic is structured around several Verilog modules, including `final_project_top`, `char_gen`, `speed_gen`, `bg_gen`, `monster_gen`, `offset_gen`, `sound_gen`, and `pixel_gen`[cite: 9].

---

## ✨ Game Overview and Rules

[cite_start]The game is a vertical-scrolling jumper where the user controls the horizontal position of a character[cite: 14].

### Basic Gameplay
* [cite_start]The character **bounces** when landing on platforms or monsters[cite: 16].
* [cite_start]The user wins when the character reaches the **top of the screen**[cite: 18].
* [cite_start]The user loses when the character **falls to the bottom** of the screen or **bumps into a monster while bouncing upwards**[cite: 18].
* [cite_start]The seven-segment display shows the **current height** (corresponding to the screen's bottom edge) during the game[cite: 19].

### Game States
[cite_start]The game operates in three main states[cite: 21, 28]:

1.  [cite_start]**Init (Initial):** The user presses the **spacebar** to start the game[cite: 24]. [cite_start]The display shows "----"[cite: 58].
2.  **Play:** The game is active. [cite_start]The state transitions to **Finish** upon a win or loss[cite: 26]. [cite_start]The display shows the `base_y` (current height)[cite: 58].
3.  [cite_start]**Finish:** The game shows the result (win: "-win"; lose: "lose") before returning to the **Init** state after **2 seconds**[cite: 28, 59].


### Special Features
* **Invincibility Mode:** When switch `sw[0]` is on, the user cannot lose. [cite_start]Monsters do not affect the character, and the character bounces back up upon hitting the bottom of the screen[cite: 20].
* [cite_start]**Shifting Platforms (Optional Feature):** Successfully implemented platforms that shift horizontally, adding a layer of difficulty[cite: 391].

---

## 🛠️ Implementation Highlights

The project overcame several hardware design challenges to achieve realistic gameplay:

### 1. Vertical Background Scrolling
[cite_start]To handle the vertical movement, the system uses **two coordinate systems**: one for the character's **absolute position** (`char_y`) and one for its **relative position on the screen** (`pos_y`)[cite: 407, 41]. [cite_start]The background scrolling is controlled by `base_y`, which represents the bottom edge of the scrolling background[cite: 46]. [cite_start]To save memory, the background is represented using a small **$8 \times 12$ grid** instead of storing every pixel[cite: 410, 414, 220].

### 2. Horizontal Platform Shifting
[cite_start]Moving platforms were challenging as they could span multiple grid blocks[cite: 418]. [cite_start]This was solved by using a **10-bit `offset` value** for each platform, which specifies its position relative to the grid edge, enabling precise horizontal movement simulation[cite: 419, 420, 267]. [cite_start]The offset value updates at each `clk21` clock edge, oscillating between two edges[cite: 275, 280, 282, 287].

### 3. Realistic Bouncing Effect
[cite_start]Simulating the character's motion (constant acceleration for bouncing) directly in Verilog was avoided due to the difficulty of floating-point calculations[cite: 422, 423]. [cite_start]Instead, a **Python script (`speed.py`)** was used to **precompute** the motion behavior, and the resulting displacement values (a 200-bit memory array) were hardcoded into the `speed_gen` module[cite: 423, 424, 194]. [cite_start]This ensures smooth, realistic vertical movement[cite: 204, 205, 209].

---
