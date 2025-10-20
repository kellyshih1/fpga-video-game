# 🎮 FPGA Doodle Jump

This project is the final report for the CS2104 Hardware Design Lab, detailing the implementation of a classic Doodle Jump game on an **Xilinx Artix-7 FPGA board**. The game features real-time control, a dynamically scrolling background, sound effects, and custom logic to simulate physics like bouncing and gravity.

## 💻 Technologies and Hardware

This project was developed using a hardware description language for implementation on the following physical components:

* **FPGA Board**
* **Keyboard** (PS/2) for character control
* **VGA Display** for graphics
* **Pmod Audio Amplifier** for sound
* **Seven-Segment Display** for in-game information (current height/game state)

The game's logic is structured around several Verilog modules, including `final_project_top`, `char_gen`, `speed_gen`, `bg_gen`, `monster_gen`, `offset_gen`, `sound_gen`, and `pixel_gen`.

---

## ✨ Game Overview and Rules

The game is a vertical-scrolling jumper where the user controls the horizontal position of a character.

### Basic Gameplay
* The character **bounces** when landing on platforms or monsters.
* The user wins when the character reaches the **top of the screen**.
* The user loses when the character **falls to the bottom** of the screen or **bumps into a monster while bouncing upwards**.
* The seven-segment display shows the **current height** (corresponding to the screen's bottom edge) during the game.

### Game States
The game operates in three main states:

1.  **Init (Initial):** The user presses the **spacebar** to start the game. The display shows "----".
2.  **Play:** The game is active. The state transitions to **Finish** upon a win or loss. The display shows the `base_y` (current height).
3.  **Finish:** The game shows the result (win: "-win"; lose: "lose") before returning to the **Init** state after **2 seconds**.


### Special Features
* **Invincibility Mode:** When switch `sw[0]` is on, the user cannot lose. Monsters do not affect the character, and the character bounces back up upon hitting the bottom of the screen.
* **Shifting Platforms (Optional Feature):** Successfully implemented platforms that shift horizontally, adding a layer of difficulty.

---

## 🛠️ Implementation Highlights

The project overcame several hardware design challenges to achieve realistic gameplay:

### 1. Vertical Background Scrolling
To handle the vertical movement, the system uses **two coordinate systems**: one for the character's **absolute position** (`char_y`) and one for its **relative position on the screen** (`pos_y`). The background scrolling is controlled by `base_y`, which represents the bottom edge of the scrolling background. To save memory, the background is represented using a small **$8 \times 12$ grid** instead of storing every pixel.

### 2. Horizontal Platform Shifting
Moving platforms were challenging as they could span multiple grid blocks. This was solved by using a **10-bit `offset` value** for each platform, which specifies its position relative to the grid edge, enabling precise horizontal movement simulation. The offset value updates at each `clk21` clock edge, oscillating between two edges.

### 3. Realistic Bouncing Effect
Simulating the character's motion (constant acceleration for bouncing) directly in Verilog was avoided due to the difficulty of floating-point calculations. Instead, a **Python script (`speed.py`)** was used to **precompute** the motion behavior, and the resulting displacement values (a 200-bit memory array) were hardcoded into the `speed_gen` module. This ensures smooth, realistic vertical movement.

---
