# Test Jig Board Generator

Project Owner : Jan Kåre Vatne (jkvatne@online.no)

# Description
This is a Altium Script project that contains a Delphi Script for importing testjig data.
It takes a gerber file generated by Macaos, and generates a PcbDoc file with pads for test pins, and a connector for measurements. Net names are imported, and a board outline is defined according to gerber data.

# How to use
Open the project in Altiuim Designer, and select Run from the menu. It will generate a new PcbDoc document with a new pcb. 

# Customization
There are a few constants at the top of the file that can fine tue hole diameters etc.
There is also a default file name. Setting it to a file path skip the file-open dialog.

The pin sizes are set to allow 2mm test pin minimum distance with 0.2mm clearance and 0.3mm anualar ring.
