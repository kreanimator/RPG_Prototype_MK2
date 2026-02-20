extends TorsoAction


func setup_animator(_input : InputPackage):
	simple_torso.play(animation, 0.15)
	parent_behaviour.legs.simple_animator.play(animation, 0.15)
