Raytracing in real-time on the GPU
##################################

Real-time raytracer implemented in HLSL. The raytracer runs on the GPU, not the CPU. This allows for parallelization pf pixel calculations on the GPU's shader units, resulting in thousand-fold speedup for the raytracing process, compared to `software rendering <https://github.com/philiparvidsson/raytracing>`_.

Features
========

* Adaptive antialiasing (not working too well)
* Keyboard controls
* Parallelization through use of shader units on GPU
* Phong shading model
* Soft shadows/shadow ray sampling

.. image:: assets/images/image_2016-11-28_05-54-29.png

Building and Running
========

1. Clone this repository.
2. Chdir into the project root.
3. Type :code:`python make.py init all run`
