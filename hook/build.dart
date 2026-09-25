import 'package:flutter_scene/build_hooks.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
// flutter_scene:init:start
    // `buildScenes` used to go here. It discovered the twenty `.glb` under
    // assets/, compiled each into a `.fsceneb` under `flutter_scene_generated/`
    // and shipped all six megabytes of them; `loadScene` then resolved a model
    // back by its `.glb` source path. Phase 5 fetches the same containers from
    // storage instead, so nothing is compiled at build time and nothing is
    // bundled. The `.glb` sources stay in the repo — they are what the bake
    // produces and what `tool/upload_tracks.py` records the provenance of —
    // and restoring this one line is how to regenerate them locally if a
    // flutter_scene upgrade ever needs the containers rebuilt.
    //
    // Compile .fmat materials under assets/, loadable by source path with
    // loadFmatMaterial (and hot-reloadable). A no-op when there are none.
    await buildMaterials(buildInput: input, buildOutput: output);
// flutter_scene:init:end
  });
}
