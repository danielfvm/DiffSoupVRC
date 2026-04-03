# DiffSoupVRC
DiffSoup implementation for VRChat. You can find the original paper's project page [here](https://github.com/kenji-tojo/diffsoup/). Most of this repositorie's code
was taken from the [Web Viewer](https://github.com/kenji-tojo/diffsoup/blob/main/web/index.html) and converted to HLSL.
On the same page you can also find a link to pre generated meshes (use the Mobile version) if you want to test it yourself and do not have the compute power to generate your own meshes.
<img width="2417" height="1165" alt="image" src="https://github.com/user-attachments/assets/888d3635-1dac-4b9c-8db9-7aabe3abe5c7" />

## Example
You can check out the example VRChat World [here](https://vrchat.com/home/world/wrld_84305a14-48a6-4397-8199-dd108ff88adc/info)

## Usage
To load a model select in the Menu `DiffSoup > Load` and select the folder that contains the model.
This folder should include following files:
```
Model/
  - lut0.png
  - lut1.png
  - mesh.ply
  - meta.json
  - mlp_weights.json
```
After importing, it will generate in the same folder a `material.mat` and a `mesh.asset` used by the model.
By default `lut0.png` and `lut1.png` will automatically be imported to use Compression, for better Quality disable Compression.
For Quest/Mobile you should ideally keep the Compression to make sure the World is small enough to be uploaded.

## Known issues / ToDos:
- Currently the view vector `v` in `DiffSoupGeometry.shader` does not match the result of the Original which leads to a worse final result.
- The shader requires a bunch of matrices to be set, since MaterialPropertyBlocks are not serialized the only work around I found is to attach an UdonBehaviour that sets the matrices at runtime.
- Currently everytime one is loading a model it is Reimporting the LUT textures even if they use the same textures as before -> long loading time due to compression.
- There is also no option to load a model without compressing it. User has to manually select no compression in LUT texture.
- Original paper uses two passes which might be more performent then doing everything in one like it is right now, but idk how to do this in VRChat.

## Credits
- Original paper's [github page](https://github.com/kenji-tojo/diffsoup/)
- [unity_ply_loader](https://github.com/andy-thomason/unity_ply_loader)
