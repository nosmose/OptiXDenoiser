#!/usr/bin/env python
# Simple Nuke script to test the OptiXDenoiser node

import nuke

# Create a test pattern
test = nuke.nodes.Checkerboard2()
test['format'].setValue('HD_1080')

# Add noise
noise = nuke.nodes.Noise()
noise.setInput(0, test)
noise['size'].setValue(3)
noise['zoffset'].setValue(1)

# Add OptiXDenoiser
denoiser = nuke.nodes.OptiXDenoiser()
denoiser.setInput(0, noise)

# Add a viewer
viewer = nuke.nodes.Viewer()
viewer.setInput(0, denoiser)

# Print success message
print("Test script created with OptiXDenoiser node")
print("If you don't see any OptiX errors in the console, the plugin is working correctly!")
