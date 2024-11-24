# VRtexShaderArt

A client to load and serve shaders loaded from  [VertexShaderArt](vertexshaderart.com) using [LOVR](lovr.org).

The original shaders are written in WEbGL 1.0, which needs some massaging before being loaded in the OpenGL 4.6 used by LOVR. 
Many features might be broken or missing, and any reference to a more structured way to do it would be greatly appreciated.

The sound data is available, although reverse engineering the Javascript `getFloatFrequencyData` isn0t very fun so there might be some inconsistencies.

More details about the work can be found in the [Notes file](./Notes.md)