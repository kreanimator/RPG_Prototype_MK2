extends TorsoAction


func on_enter_action(input : InputPackage):
	super.on_enter_action(input)

func setup_animator(_input : InputPackage):
	simple_torso.play(animation, 0.15)
