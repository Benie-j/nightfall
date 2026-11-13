extends SceneTree

const REQUIRED_MODELS := [
    "res://hero.glb",
    "res://assets/external/soldier.glb",
    "res://assets/external/m4a1_fp.glb",
    "res://assets/external/covered_car.glb"
]

func _initialize() -> void:
    call_deferred("_validate")

func _validate() -> void:
    var failed := false

    for model_path in REQUIRED_MODELS:
        var resource := ResourceLoader.load(model_path)

        if not resource is PackedScene:
            push_error("MODELE 3D INVALIDE : " + model_path)
            failed = true
        else:
            print("MODELE 3D VALIDE : " + model_path)

    quit(1 if failed else 0)
