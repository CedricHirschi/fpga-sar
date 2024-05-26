# FPGA-SAR

Material for the SAR ADC project in the **iCEBreaker FPGA For IoT Sensing Systems** FS2024 course.

## Project Description

Build a SAR ADC and a way to read its values.
- [x] Build analog part (See [hardware/](hardware/))
- [x] Develop SAR core (See [verilog/](verilog/))
- [x] Develop UART readout core (See [verilog/](verilog/))
- [ ] Optional: Evaluate speed and accuracy

## Project Structure

- [hardware/](hardware/): Contains the KiCad project for the analog part of the SAR ADC
- [verilog/](verilog/): Contains the Verilog code for the SAR ADC and UART readout core
- [gui.ipynb](gui.ipynb): Jupyter notebook for plotting the ADC values
- [activate.sh](activate.sh): Script to activate the virtual environment for development with APIO and Jupyter Notebook
- [presentation.pptx](presentation.pptx): Presentation slides for the project
