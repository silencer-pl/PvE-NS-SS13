//Critical defines go here. Why here and not where Cm keeps its ohter defines? Because I'm tired of constantly having to look somewhere else during dev.


/mob/living/pve_boss
	icon = 'icons/Surge/surge_default.dmi'
	icon_state = "default"
	name = "Boss entities and associated procs. This should not be out in the wild."
	sight = SEE_SELF|SEE_MOBS|SEE_OBJS|SEE_TURFS|SEE_THRU|SEE_INFRA
	lighting_alpha = LIGHTING_PLANE_ALPHA_INVISIBLE
	//Xenosurge vars that go here for same reasons as above
	var/boss_type = "default"
	//below should be safely disregarded if type is not set to 1
	var/boss_shield = 0 // This will also be the shields max value on spawn for simplicity
	var/boss_shield_cooldown = 0

	var/boss_shield_max = 0
	var/boss_shield_broken_timestamp = 0
	var/boss_no_damage = 0

	var/datum/boss_action/boss_ability //The main ability datum, containing ALL boss abilities. Said datum is pretty disorganized :P

	var/list/boss_abilities_list = list("StandardAttack" = 5,) // Abiltity Name for referencing in pcos = cooldown timer.

	// None of these should be touched, they are used by the datums for reference.
	var/current_ability
	var/action_activated = 0
	var/list/action_last_use_time = list()

	//Individual skill values should also be defined here. This can be pushed down the tree by messing with the boss_ability datum (specfically plug in something from down its own tree to it with a custom set or waht have you), but I dont feel like doing that.
	var/standard_attack_cooldown = 30 //Meant to be separate from individual attacks, the frequency of base attacking. Should be adjusted depending on strength of individual attacks
	var/standard_range_salvo_count = 3
	var/standard_range_salvo_delay = 3
	var/explosion_damage = 30
	var/aoe_delay = 40
	var/missile_storm_missiles = 25

	//movement resuming after destruction calls
	var/turf/movement_target

/mob/living/pve_boss/Initialize()
	. = ..()
	boss_ability = new /datum/boss_action/(boss = src)
	click_intercept = new /datum/bossclicking/(boss = src)
	action_last_use_time = boss_abilities_list.Copy()
	boss_shield_max = boss_shield

/mob/living/pve_boss/update_icons()
	overlays.Cut()
	overlays += image(icon, src, icon_state)

/mob/living/pve_boss/Bump(Obstacle)
	if(istype(Obstacle, /turf/closed))
		var/turf/closed/bumped_turf = Obstacle
		var/saved_icon = bumped_turf.icon
		var/saved_icon_state
		if(istype(Obstacle, /turf/closed/wall))
			var/turf/closed/wall/no_base_icon_state_turf = Obstacle
			saved_icon_state = no_base_icon_state_turf.walltype
		else
			saved_icon_state = bumped_turf.icon_state
		var/saved_turf_x = bumped_turf.x
		var/saved_turf_y = bumped_turf.y
		var/saved_turf_z = bumped_turf.z
		var/saved_dir = bumped_turf.dir
		bumped_turf.ScrapeAway(INFINITY, CHANGETURF_DEFER_CHANGE)
		var/turf_ref = locate(saved_turf_x,saved_turf_y,saved_turf_z)
		boss_ability.icon_chunk(saved_icon,saved_icon_state,saved_dir,turf_ref)
		new /obj/effect/shockwave(bumped_turf, 3)
	if(istype(Obstacle, /turf/open))
		var/turf/open/open_turf = Obstacle
		src.forceMove(open_turf)
	if(istype(Obstacle, /obj))
		var/obj/bumped_obj = Obstacle
		var/saved_icon = bumped_obj.icon
		var/saved_icon_state = bumped_obj.icon_state
		var/turf/saved_turf = get_turf(bumped_obj)
		var/saved_dir = bumped_obj.dir
		qdel(bumped_obj)
		boss_ability.icon_chunk(saved_icon,saved_icon_state,saved_dir,saved_turf)
		new /obj/effect/shockwave(saved_turf, 3)
	if(istype(Obstacle, /mob))
		var/mob/bumped_mob = Obstacle
		var/facing = get_dir(get_turf(src), bumped_mob)
		var/turf/throw_turf = get_turf(src)
		var/turf/temp = get_turf(src)

		for (var/x in 0 to 3)
			temp = get_step(throw_turf, facing)
			if (!temp)
				break
			throw_turf = temp
		bumped_mob.throw_atom(throw_turf, 4, SPEED_VERY_FAST, src, TRUE)
	if(movement_target) boss_ability.accelerate_to_target(movement_target, on_bump = TRUE)
	. = ..()

/obj/item/prop/shield_ping
	name = "Shield ping icon animation."
	opacity = FALSE
	mouse_opacity = FALSE
	anchored = TRUE
	indestructible = TRUE
	blend_mode = BLEND_OVERLAY
	layer = ABOVE_MOB_LAYER
	icon = 'icons/Surge/boss_bot/boss.dmi'
	icon_state = "shield"

/mob/living/pve_boss/proc/animate_shield(type)
	if(!type) return
	var/obj/item/prop/shield_ping/ping_object = new()
	if(boss_shield > 0)
		switch(boss_shield_max / boss_shield)
			if(0.9 to 1)
				ping_object.color = "#FF0000"
			if(0.8 to 0.9)
				ping_object.color = "#ff4d4d"
			if(0.7 to 0.8)
				ping_object.color = "#ff8b8b"
			if(0.6 to 0.7)
				ping_object.color = "#ffb9b9"
			if(0.5 to 0.6)
				ping_object.color = "#fdc7c7"
			if(0.4 to 0.5)
				ping_object.color = "#ffdcdc"
			if(0.3 to 0.4)
				ping_object.color = "#ffe6e6"
			if(0.2 to 0.3)
				ping_object.color = "#ffe7e7"
			if(0.1 to 0.2)
				ping_object.color = "#fff0f0"
			if(0 to 0.1)
				ping_object.color = "#fff1f1"
			else
				ping_object.color = "#ff0000"
	else
		ping_object.color = "#cfafaf"
	switch(type)
		if(1)
			ping_object.alpha = 1
			animate(ping_object,alpha = 255, easing = CIRCULAR_EASING|EASE_IN, time = 2)
			animate(alpha = 1, easing = CIRCULAR_EASING|EASE_OUT, time = 2)
		if(2)
			ping_object.alpha = 255
			var/matrix/A = matrix()
			A.Scale(3)
			animate(ping_object,alpha = 1,transform = A, easing = SINE_EASING|EASE_IN, time = 3)
		if(2)
			ping_object.alpha = 255
			var/matrix/A = matrix()
			A.Scale(3)
			animate(ping_object,alpha = 1,transform = A, easing = SINE_EASING|EASE_IN, time = 3)
		if(3)
			ping_object.alpha = 1
			var/matrix/A = matrix()
			var/matrix/B = matrix()
			A.Scale(2)
			apply_transform(A)
			B.Scale(1)
			animate(ping_object,alpha = 255,transform = B, easing = SINE_EASING|EASE_IN, time = 3)
			animate(alpha = 1, easing = SINE_EASING|EASE_IN, time = 1)

	src.vis_contents += ping_object
	sleep(5)
	src.vis_contents -= ping_object
	qdel(ping_object)

/mob/living/pve_boss/proc/restart_shield()
	if(world.time < boss_shield_broken_timestamp + boss_shield_cooldown)
		sleep(10)
		restart_shield()
		return
	else
		boss_shield = boss_shield_max
		INVOKE_ASYNC(src, TYPE_PROC_REF(/mob/living/pve_boss/, animate_shield), 3)
		return

/mob/living/pve_boss/proc/BossStage()
	boss_no_damage = 1
	if(GLOB.boss_stage < GLOB.boss_stage_max)
		GLOB.boss_stage += 1
		animate(src, pixel_x = 200, time = 10, easing = CUBIC_EASING|EASE_IN)
		sleep(10)
		qdel(src)
	else
		src.death(gibbed = FALSE, deathmessage = "loses power to its engines, spins in place, smashes into the ground and shuts down.", should_deathmessage = TRUE)

/mob/living/pve_boss/proc/animate_hit()
	var/color_value = "#FFFFFF"
	var/pixel_x_org = pixel_x
	var/pixel_y_org = pixel_y
	var/pixel_x_val = rand(0,2)
	var/pixel_y_val = rand(0,2)
	if(health <= 0)
		color_value = "#FF0000"
	else
		switch(maxHealth / health)
			if(0.9 to 1)
				color_value = "#ffecdd"
			if(0.8 to 0.9)
				color_value = "#ffdfc5"
			if(0.7 to 0.8)
				color_value = "#ffcba1"
			if(0.6 to 0.7)
				color_value = "#ffbf8b"
			if(0.5 to 0.6)
				color_value = "#ffb272"
			if(0.4 to 0.5)
				color_value = "#ffa052"
			if(0.3 to 0.4)
				color_value= "#ff8928"
			if(0.2 to 0.3)
				color_value = "#ff811a"
			if(0.1 to 0.2)
				color_value = "#ff790b"
			if(0 to 0.1)
				color_value = "#ff5e00"
			else
				color_value = "#ff5e00"
	animate(src, pixel_x = pixel_x_val, pixel_y = pixel_y_val, color = color_value, time = 1, flags = ANIMATION_PARALLEL)
	animate(color = "#FFFFFF", pixel_x = pixel_x_org, pixel_y = pixel_y_org, time = 1, flags = ANIMATION_PARALLEL)


/mob/living/pve_boss/apply_damage(damage, damagetype, def_zone, used_weapon, sharp, edge, force)
	if(boss_no_damage == 1) return
	var/damage_ammount = damage
	if(boss_shield > 0)
		boss_shield -= damage_ammount
		if(boss_shield < 0) boss_shield = 0
		if(boss_shield > 0)
			INVOKE_ASYNC(src, TYPE_PROC_REF(/mob/living/pve_boss/, animate_shield), 1)
		else
			INVOKE_ASYNC(src, TYPE_PROC_REF(/mob/living/pve_boss/, animate_shield), 2)
			boss_shield_broken_timestamp = world.time
			INVOKE_ASYNC(src, TYPE_PROC_REF(/mob/living/pve_boss/, restart_shield))
		return
	else
		if((health - damage) <= 0)
			health = 0
			BossStage()
			return
		else
			health -= damage
			INVOKE_ASYNC(src, TYPE_PROC_REF(/mob/living/pve_boss/, animate_hit))

/datum/boss_action/

	var/mob/owner = null


/datum/boss_action/New(mob/boss)
	. = ..()
	owner = boss

/datum/boss_action/proc/apply_cooldown(current_ability)
	var/mob/living/pve_boss/boss_mob = owner
	boss_mob.action_last_use_time[current_ability] = world.time

/datum/boss_action/proc/action_cooldown_check(current_ability)
	var/mob/living/pve_boss/boss_mob = owner
	if(boss_mob.action_activated) return 0
	if(!boss_mob.action_last_use_time[current_ability])
		return 1
	else if(world.time > boss_mob.action_last_use_time[current_ability] + boss_mob.boss_abilities_list[current_ability])
		return 1
	else
		return 0

/datum/boss_action/proc/usage_cooldown_loop(amount)
	var/mob/living/pve_boss/boss_mob = owner
	if(!amount) return
	boss_mob.action_activated = 1
	sleep(amount)
	boss_mob.action_activated = 0

/mob/living/pve_boss/proc/AnimateEntry()
	return
