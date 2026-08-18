# The scene

> Owns: src/qml/Main.qml
> Owns: src/qml/SpinningTriangle.qml
> See:  docs/app.md

An equilateral triangle spinning about its centroid, on a flat background.

**The centroid is not the centre of the bounding box.** It sits a third of the triangle's
height from the base, not half. `SpinningTriangle` places the three vertices around the
item's centre so that the default `transformOrigin` is already the centroid; give the shape
its natural bounding box instead and the rotation still works, it just wobbles — which
looks like a frame-pacing problem and is not one.

**Nothing here draws text.** A Qt image with no font installed renders an empty rectangle
where a string should be and logs nothing, so a boot check written against on-screen text
reports a failure that belongs to the image and not to the application. Adding text means
adding a font package on the image side first — `qt-hmi-buildroot/docs/build-pipeline.md`.

`Window` sets 1280x720. Under `eglfs` that size is ignored and the window takes the whole
connector; it is the desktop window size, and on both targets the aspect the scene is laid
out against.
