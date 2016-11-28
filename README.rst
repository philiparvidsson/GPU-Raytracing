Raytracing in real-time on the GPU
##################################

Real-time raytracer implemented in HLSL.

Features
========

* Parallelization through use of shader units on GPU
* Adaptive antialiasing (not working too well)
* Soft shadows/shadow ray sampling

.. image:: assets/images/image_2016-11-28_05-54-29.png

Building
========

1. Clone this repository.
2. Chdir into the project root.
3. Type :code:`pythom make.py init && make python.py make && python make.py run`
