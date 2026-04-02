# DiffSoupVRC
DiffSoup implementation for VRChat. You can find the original project page [here](https://github.com/kenji-tojo/diffsoup/)
On that page you can also find a link to pre generated meshes.

## Usage
To load a model select in the Menu DiffSoup > Load and select the folder that contains the model.
This folder should include following files:
```
Model/
  - lut0.png
  - lut1.png
  - mesh.ply
  - meta.json
  - mlp_weights.json
```
After importing it will generate in the same folder a `material.mat` and a `mesh.asset` used by the model.
By default `lut0.png` and `lut1.png` will automatically be imported to use Compression, for better Quality disable Compression.

## Known issues / ToDos:
- Currently the view vector `v` in `DiffSoupGeometry.shader` does not match the result of the Original which leads to a worse final result.
- The shader requires a bunch of matrices to be set, since MaterialPropertyBlocks are not serialized the only work around I found is to attach an UdonBehaviour that sets the matrices at runtime.
- Currently everytime one is loading a model it is Reimporting the LUT textures even if they use the same textures as before -> long loading time duo to compression.
- There is also no option to load a model without compressing it. User has to manually select no compression in LUT texture.
- Original paper uses two passes which might be more performent then doing everything in one like it is right now, but idk how to do this in VRChat.
