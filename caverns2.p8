pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- [initialization]
-- evercore v2.3.1

function vector(x,y)
	return {x=x,y=y}
end

function rectangle(x,y,w,h)
	return {x=x,y=y,w=w,h=h}
end

-- global tables
objects,collected={},{}
-- global timers
freeze,delay_restart,sfx_timer,music_timer,ui_timer=0,0,0,0,-99
-- global camera values
draw_x,draw_y,cam_x,cam_y,cam_spdx,cam_spdy,cam_gain=0,0,0,0,0,0,0.25

-- [entry point]

function _init()
	frames,start_game_flash=0,0
	music(40,0,7)
	lvl_id=0
end

function begin_game()
	max_djump=1
	deaths,frames,seconds_f,minutes,music_timer,time_ticking,fruit_count,bg_col,cloud_col=0,0,0,0,0,true,0,0,1
	music(0,0,7)
	load_level(1)
end

function is_title()
	return lvl_id==0
end

-- [effects]

clouds={}
for i=0,16 do
	add(clouds,{
		x=rnd"128",
		y=rnd"128",
		spd=1+rnd"4",
	w=32+rnd"32"})
end

particles={}
for i=0,24 do
	add(particles,{
		x=rnd"128",
		y=rnd"128",
		s=flr(rnd"1.25"),
		spd=0.25+rnd"5",
		off=rnd(),
		c=6+rnd"2",
	})
end

dead_particles={}

-- [function library]

function psfx(num)
	if sfx_timer<=0 then
		sfx(num)
	end
end

function round(x)
	return flr(x+0.5)
end

function appr(val,target,amount)
	return val>target and max(val-amount,target) or min(val+amount,target)
end

function sign(v)
	return v~=0 and sgn(v) or 0
end

function two_digit_str(x)
	return x<10 and "0"..x or x
end

function tile_at(x,y)
	return mget(lvl_x+x,lvl_y+y)
end

function spikes_at(x1,y1,x2,y2,xspd,yspd)
	for i=max(0,x1\8),min(lvl_w-1,x2/8) do
		for j=max(0,y1\8),min(lvl_h-1,y2/8) do
			if({[17]=y2%8>=6 and yspd>=0,
			[27]=y1%8<=2 and yspd<=0,
			[43]=x1%8<=2 and xspd<=0,
			[59]=x2%8>=6 and xspd>=0})[tile_at(i,j)] then
				return true
			end
		end
	end
end
-->8
-- [update loop]

function _update()
	frames+=1
	if time_ticking then
		seconds_f+=1
		minutes+=seconds_f\1800
		seconds_f%=1800
	end
	frames%=30

	if music_timer>0 then
		music_timer-=1
		if music_timer<=0 then
			music(10,0,7)
		end
	end

	if sfx_timer>0 then
		sfx_timer-=1
	end

	-- cancel if freeze
	if freeze>0 then
		freeze-=1
		return
	end

	-- restart (soon)
	if delay_restart>0 then
		cam_spdx,cam_spdy=0,0
		delay_restart-=1
		if delay_restart==0 then
			load_level(lvl_id)
		end
	end

	-- update each object
	foreach(objects,function(obj)
		obj.move(obj.spd.x,obj.spd.y,0);
		(obj.type.update or stat)(obj)
	end)

	-- move camera to player
	foreach(objects,function(obj)
		if obj.type==player or obj.type==player_spawn then
			move_camera(obj)
		end
	end)

	-- start game
	if is_title() then
		if start_game then
			start_game_flash-=1
			if start_game_flash<=-30 then
				begin_game()
			end
		elseif btn(🅾️) or btn(❎) then
			music"-1"
			start_game_flash,start_game=50,true
			sfx"38"
		end
	end
end
-->8
-- [draw loop]

function _draw()
	if freeze>0 then
		return
	end

	-- reset all palette values
	pal()

	-- start game flash
	if is_title() then
		if start_game then
			for i=1,15 do
				pal(i, start_game_flash<=10 and ceil(max(start_game_flash)/5) or frames%10<5 and 7 or i)
			end
		end

		cls()

		-- credits
		sspr(unpack(split"72,32,56,32,36,32"))
		?"🅾️/❎",55,80,5
		?"maddy thorson",40,96,5
		?"noel berry",46,102,5

		-- particles
		foreach(particles,draw_particle)

		return
	end

	-- draw bg color
	cls(flash_bg and frames/5 or bg_col)

	-- bg clouds effect
	foreach(clouds,function(c)
		c.x+=c.spd-cam_spdx
		rectfill(c.x,c.y,c.x+c.w,c.y+16-c.w*0.1875,cloud_col)
		if c.x>128 then
			c.x=-c.w
			c.y=rnd"120"
		end
	end)

	-- set cam draw position
	draw_x=round(cam_x)-64
	draw_y=round(cam_y)-64
	camera(draw_x,draw_y)

	-- draw bg terrain
	map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,4)
	
	-- set draw layering
	-- positive layers draw after player
	-- layer 0 draws before player, after terrain
	-- negative layers draw before terrain
	local pre_draw,post_draw={},{}
	foreach(objects,function(obj)
		local draw_grp=obj.layer<0 and pre_draw or post_draw
		for k,v in ipairs(draw_grp) do
			if obj.layer<=v.layer then
				add(draw_grp,obj,k)
				return
			end
		end
		add(draw_grp,obj)
	end)

	-- draw bg objects
	foreach(pre_draw,draw_object)
	
	-- draw terrain
	map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,2)
	
	-- draw fg objects
	foreach(post_draw,draw_object)

	-- draw jumpthroughs
	map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,8)

	-- particles
	foreach(particles,draw_particle)

	-- dead particles
	foreach(dead_particles,function(p)
		p.x+=p.dx
		p.y+=p.dy
		p.t-=0.2
		if p.t<=0 then
			del(dead_particles,p)
		end
		rectfill(p.x-p.t,p.y-p.t,p.x+p.t,p.y+p.t,14+5*p.t%2)
	end)

	-- draw level title
	camera()
	if ui_timer>=-30 then
		if ui_timer<0 then
			draw_ui()
		end
		ui_timer-=1
	end
end

function draw_particle(p)
	p.x+=p.spd-cam_spdx
	p.y+=sin(p.off)-cam_spdy
	p.off+=min(0.05,p.spd/32)
	rectfill(p.x+draw_x,p.y%128+draw_y,p.x+p.s+draw_x,p.y%128+p.s+draw_y,p.c)
	if p.x>132 then
		p.x=-4
		p.y=rnd"128"
	elseif p.x<-4 then
		p.x=128
		p.y=rnd"128"
	end
end

function draw_time(x,y)
	rectfill(x,y,x+44,y+6,0)
	?two_digit_str(minutes\60)..":"..two_digit_str(minutes%60)..":"..two_digit_str(seconds_f\30).."."..two_digit_str(round(seconds_f%30*100/30)),x+1,y+1,7
end

function draw_ui()
	rectfill(24,58,104,70,0)
	local title=lvl_title or lvl_id.."00 m"
	?title,64-#title*2,62,7
	draw_time(4,4)
end
-->8
-- [player class]

player={
	init=function(this)
		this.grace,this.jbuffer=0,0
		this.djump=max_djump
		this.dash_time,this.dash_effect_time=0,0
		this.dash_target_x,this.dash_target_y=0,0
		this.dash_accel_x,this.dash_accel_y=0,0
		this.hitbox=rectangle(1,3,6,5)
		this.spr_off=0
		this.collides=true
		create_hair(this)
		
		this.layer=1
	end,
	update=function(this)
		if pause_player then
			return
		end

		-- horizontal input
		local h_input=btn(➡️) and 1 or btn(⬅️) and -1 or 0

		-- spike collision / bottom death
		if spikes_at(this.left(),this.top(),this.right(),this.bottom(),this.spd.x,this.spd.y) or this.y>lvl_ph then
			kill_player(this)
		end

		-- on ground checks
		local on_ground=this.is_solid(0,1)

		-- landing smoke
		if on_ground and not this.was_on_ground then
			this.init_smoke(0,4)
		end

		-- jump and dash input
		local jump,dash=btn(🅾️) and not this.p_jump,btn(❎) and not this.p_dash
		this.p_jump,this.p_dash=btn(🅾️),btn(❎)

		-- jump buffer
		if jump then
			this.jbuffer=4
		elseif this.jbuffer>0 then
			this.jbuffer-=1
		end

		-- grace frames and dash restoration
		if on_ground then
			this.grace=6
			if this.djump<max_djump then
				psfx"54"
				this.djump=max_djump
			end
		elseif this.grace>0 then
			this.grace-=1
		end

		-- dash effect timer (for dash-triggered events, e.g., berry blocks)
		this.dash_effect_time-=1

		-- dash startup period, accel toward dash target speed
		if this.dash_time>0 then
			this.init_smoke()
			this.dash_time-=1
			this.spd=vector(appr(this.spd.x,this.dash_target_x,this.dash_accel_x),appr(this.spd.y,this.dash_target_y,this.dash_accel_y))
		else
			-- x movement
			local maxrun=1
			local accel=this.is_ice(0,1) and 0.05 or on_ground and 0.6 or 0.4
			local deccel=0.15

			-- set x speed
			this.spd.x=abs(this.spd.x)<=1 and
			appr(this.spd.x,h_input*maxrun,accel) or
			appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)

			-- facing direction
			if this.spd.x~=0 then
				this.flip.x=this.spd.x<0
			end

			-- y movement
			local maxfall=2

			-- wall slide
			if h_input~=0 and this.is_solid(h_input,0) and not this.is_ice(h_input,0) then
				maxfall=0.4
				-- wall slide smoke
				if rnd"10"<2 then
					this.init_smoke(h_input*6)
				end
			end

			-- apply gravity
			if not on_ground then
				this.spd.y=appr(this.spd.y,maxfall,abs(this.spd.y)>0.15 and 0.21 or 0.105)
			end

			-- jump
			if this.jbuffer>0 then
				if this.grace>0 then
					-- normal jump
					psfx"1"
					this.jbuffer=0
					this.grace=0
					this.spd.y=-2
					this.init_smoke(0,4)
				else
					-- wall jump
					local wall_dir=(this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0)
					if wall_dir~=0 then
						psfx"2"
						this.jbuffer=0
						this.spd=vector(wall_dir*(-1-maxrun),-2)
						if not this.is_ice(wall_dir*3,0) then
							-- wall jump smoke
							this.init_smoke(wall_dir*6)
						end
					end
				end
			end

			-- dash
			local d_full=5
			local d_half=3.5355339059 -- 5 * sqrt(2)

			if this.djump>0 and dash then
				this.init_smoke()
				this.djump-=1
				this.dash_time=4
				has_dashed=true
				this.dash_effect_time=10
				-- vertical input
				local v_input=btn(⬆️) and -1 or btn(⬇️) and 1 or 0
				-- calculate dash speeds
				this.spd=vector(h_input~=0 and
					h_input*(v_input~=0 and d_half or d_full) or
					(v_input~=0 and 0 or this.flip.x and -1 or 1)
				,v_input~=0 and v_input*(h_input~=0 and d_half or d_full) or 0)
				-- effects
				psfx"3"
				freeze=2
				-- dash target speeds and accels
				this.dash_target_x=2*sign(this.spd.x)
				this.dash_target_y=(this.spd.y>=0 and 2 or 1.5)*sign(this.spd.y)
				this.dash_accel_x=this.spd.y==0 and 1.5 or 1.06066017177 -- 1.5 * sqrt()
				this.dash_accel_y=this.spd.x==0 and 1.5 or 1.06066017177
			elseif this.djump<=0 and dash then
				-- failed dash smoke
				psfx"9"
				this.init_smoke()
			end
		end

		-- animation
		this.spr_off+=0.25
		this.spr = not on_ground and (this.is_solid(h_input,0) and 5 or 3) or	-- wall slide or mid air
		btn(⬇️) and 6 or -- crouch
		btn(⬆️) and 7 or -- look up
		this.spd.x~=0 and h_input~=0 and 1+this.spr_off%4 or 1 -- walk or stand

		-- define arrays for levels exiting to different directions
		local single_width = {1,6,8,12} -- single-width levels
		local double_width = {2,4,5,9,11} -- double-width levels
		local exit_down_double = {13} -- levels that exit down and have height 2

		-- function to check if a level id is in a list
		local function is_in_list(level_id, list)
    for _, id in pairs(list) do
        if id == level_id then return true end
    end
    return false
		end

		-- determine level exit conditions
		if this.y < -4 and not is_in_list(lvl_id, single_width) and not is_in_list(lvl_id, double_width) and not is_in_list(lvl_id, exit_down_double) and levels[lvl_id + 1] then
    next_level() -- default: exit at the top
		elseif is_in_list(lvl_id, single_width) and this.x > 122 and levels[lvl_id + 1] then
    next_level() -- single-width level: exit to the right
		elseif is_in_list(lvl_id, double_width) and this.x > 250 and levels[lvl_id + 1] then
    next_level() -- double-width level: exit to the right
		elseif is_in_list(lvl_id, exit_down_double) and this.y > (lvl_ph - 10) and levels[lvl_id + 1] then
	next_level() -- exit down
		end 

		-- was on the ground
		this.was_on_ground=on_ground
	end,

	draw=function(this)
		-- clamp in screen
		local clamped=mid(this.x,-1,lvl_pw-7)
		if this.x~=clamped then
			this.x=clamped
			this.spd.x=0
		end
		-- draw player hair and sprite
		set_hair_color(this.djump)
		draw_hair(this)
		draw_obj_sprite(this)
		pal()
	end
}

function create_hair(obj)
	obj.hair={}
	for i=1,5 do
		add(obj.hair,vector(obj.x,obj.y))
	end
end

set_hair_color=function(djump)
	pal(9,(djump==1 and 9 or djump==2 and (11+flr((frames/3)%2)*-8) or 6))
end

function draw_hair(obj)
	local last=vector(obj.x+(obj.flip.x and 6 or 2),obj.y+(btn(⬇️) and 4 or 3))
	for i,h in ipairs(obj.hair) do
		h.x+=(last.x-h.x)/1.5
		h.y+=(last.y+0.5-h.y)/1.5
		circfill(h.x,h.y,mid(4-i,1,2),9)
		last=h
	end
end

function kill_player(obj)
	sfx_timer=12
	sfx"0"
	deaths+=1
	destroy_object(obj)
	for dir=0,0.875,0.125 do
		add(dead_particles,{
			x=obj.x+4,
			y=obj.y+4,
			t=2,
			dx=sin(dir)*3,
			dy=cos(dir)*3
		})
	end
	delay_restart=15
end

player_spawn={
	init=function(this)
		if lvl_id==13 then
			destroy_object(this)
			init_object(player,this.x,this.y)
		end
		sfx"4"
		this.spr=3
		this.target=this.y
		this.y=min(this.y+48,lvl_ph)
		cam_x,cam_y=mid(this.x+4,64,lvl_pw-64),mid(this.y,64,lvl_ph-64)
		this.spd.y=-4
		this.state=0
		this.delay=0
		create_hair(this)
		this.djump=max_djump
		
		this.layer=1
	end,
	update=function(this)
		-- jumping up
		if this.state==0 and this.y<this.target+16 then
			this.state=1
			this.delay=3
			-- falling
		elseif this.state==1 then
			this.spd.y+=0.5
			if this.spd.y>0 then
				if this.delay>0 then
					-- stall at peak
					this.spd.y=0
					this.delay-=1
				elseif this.y>this.target then
					-- clamp at target y
					this.y=this.target
					this.spd=vector(0,0)
					this.state=2
					this.delay=5
					this.init_smoke(0,4)
					sfx"5"
				end
			end
			-- landing and spawning player object
		elseif this.state==2 then
			this.delay-=1
			this.spr=6
			if this.delay<0 then
				destroy_object(this)
				init_object(player,this.x,this.y)
			end
		end
	end,
	draw= player.draw
}
-->8
-- [objects]

spring={
	init=function(this)
		this.falling=false
		this.delta=0
		this.dir=this.spr==18 and 0 or this.is_solid(-1,0) and 1 or -1
		this.show=true
		this.layer=-1
	end,
	update=function(this)
		this.delta=this.delta*0.75
		local hit=this.player_here()
		
		if this.show and hit and this.delta<=1 then
			if this.dir==0 then
				hit.move(0,this.y-hit.y-4,1)
				hit.spd.x*=0.2
				hit.spd.y=-3
			else
				hit.move(this.x+this.dir*4-hit.x,0,1)
				hit.spd=vector(this.dir*3,-1.5)
			end
			if this.falling then
				this.y += 3
			end
			hit.dash_time=0
			hit.dash_effect_time=0
			hit.djump=max_djump
			this.delta=8
			psfx"8"
			this.init_smoke()
			
			break_fall_floor(this.check(fall_floor,-this.dir,this.dir==0 and 1 or 0))
		end
	end,
	draw=function(this)
		if this.show then
		
			if this.falling then
				this.y += 3
			end
			
			local delta=min(flr(this.delta),4)
			if this.dir==0 then
				sspr(16,8,8,8,this.x,this.y+delta)
			else
				spr(19,this.dir==-1 and this.x+delta or this.x,this.y,1-delta/8,1,this.dir==1)
			end
		end
end
}
fall_floor={
	init=function(this)
		this.solid_obj=true
		this.state=0
	end,
	update=function(this)
		-- idling
		if this.state==0 then
			for i=0,2 do
				if this.check(player,i-1,-(i%2)) then
					break_fall_floor(this)
				end
			end
		-- shaking
		elseif this.state==1 then
			this.delay-=1
			if this.delay<=0 then
				this.state=2
				-- transition to falling
				
			end
		-- falling
		elseif this.state==2 then
			-- move the block downward
			set_springs(this,true)
			this.y += 3

			-- check for collision with tiles flagged as interactable (flag 1)
			local next_tile_x = this.x // 8
			local next_tile_y = (this.y + 8) // 8
			if fget(mget(next_tile_x, next_tile_y), 1) then
				-- stop falling and settle on the tile
				this.state = 3
				this.y = next_tile_y * 8
				this.collideable = true
			else
				this.collideable = true
			end
		-- invisible, waiting to reset
		elseif this.state==3 then
			if not this.player_here() then
				psfx"7"
				this.state=0
				this.collideable=true
				this.init_smoke()
				set_springs(this,true)
			end
		end
	end,
	draw=function(this)
		-- only draw the falling block; skip disappearing animation
		spr(23, this.x, this.y)
	end,
}


function break_fall_floor(obj)
	if obj and obj.state==0 then
		psfx"15"
		obj.state=1
		obj.delay=10 -- time until it falls
		obj.init_smoke()
	end
end

function set_springs(obj,state)
	obj.hitbox=rectangle(-2,-2,12,8)
	local springs=obj.check_all(spring,0,0)
	foreach(springs,function(s) s.falling=state end)
	obj.hitbox=rectangle(0,0,8,8)
end

overgrown_balloon={
	init=function(this)
		this.offset=rnd()
		this.start=this.y
		this.timer=0
		this.hitbox=rectangle(-1,-1,10,10)
	end,
	update=function(this)
		if this.spr==24 then
			this.offset+=0.01
			this.y=this.start+sin(this.offset)*2
			local hit=this.player_here()
			if hit and hit.djump<(max_djump+1) then
				psfx"6"
				this.init_smoke()
				hit.djump=max_djump + 1
				this.spr=0
				this.timer=60
			end
		elseif this.timer>0 then
			this.timer-=1
		else
			psfx"7"
			this.init_smoke()
			this.spr=24
		end
	end,
	draw=function(this)
		if this.spr==24 then
			for i=7,13 do
				pset(this.x+4+sin(this.offset*2+i/10),this.y+i,6)
			end
			draw_obj_sprite(this)
		end
	end
}

balloon={
	init=function(this)
		this.offset=rnd()
		this.start=this.y
		this.timer=0
		this.hitbox=rectangle(-1,-1,10,10)
	end,
	update=function(this)
		if this.spr==22 then
			this.offset+=0.01
			this.y=this.start+sin(this.offset)*2
			local hit=this.player_here()
			if hit and hit.djump<max_djump then
				psfx"6"
				this.init_smoke()
				hit.djump=max_djump
				this.spr=0
				this.timer=60
			end
		elseif this.timer>0 then
			this.timer-=1
		else
			psfx"7"
			this.init_smoke()
			this.spr=22
		end
	end,
	draw=function(this)
		if this.spr==22 then
			for i=7,13 do
				pset(this.x+4+sin(this.offset*2+i/10),this.y+i,6)
			end
			draw_obj_sprite(this)
		end
	end
}

smoke={
	init=function(this)
		this.spd=vector(0.3+rnd"0.2",-0.1)
		this.x+=-1+rnd"2"
		this.y+=-1+rnd"2"
		this.flip=vector(rnd()<0.5,rnd()<0.5)
		this.layer=3
	end,
	update=function(this)
		this.spr+=0.2
		if this.spr>=32 then
			destroy_object(this)
		end
	end
}

fruit={
	is_fruit=true,
	init=function(this)
		this.start=this.y
		this.off=0
	end,
	update=function(this)
		check_fruit(this)
		this.off+=0.025
		this.y=this.start+sin(this.off)*2.5
	end
}



function check_fruit(this)
	local hit=this.player_here()
	if hit then
		hit.djump=max_djump
		sfx_timer=20
		sfx"13"
		collected[this.id]=true
		init_object(lifeup,this.x,this.y)
		destroy_object(this)
		if time_ticking then
			fruit_count+=1
		end
	end
end

lifeup={
	init=function(this)
		this.spd.y=-0.25
		this.duration=30
		this.flash=0
	end,
	update=function(this)
		this.duration-=1
		if this.duration<=0 then
			destroy_object(this)
		end
	end,
	draw=function(this)
		this.flash+=0.5
		?"1000",this.x-4,this.y-4,7+this.flash%2
	end
}

fake_wall={
	is_fruit=true,
	init=function(this)
		this.solid_obj=true
		this.hitbox=rectangle(0,0,16,16)
	end,
	update=function(this)
		this.hitbox=rectangle(-1,-1,18,18)
		local hit=this.player_here()
		if hit and hit.dash_effect_time>0 then
			hit.spd=vector(sign(hit.spd.x)*-1.5,-1.5)
			hit.dash_time=-1
			for ox=0,8,8 do
				for oy=0,8,8 do
					this.init_smoke(ox,oy)
				end
			end
			init_fruit(this,4,4)
		end
		this.hitbox=rectangle(0,0,16,16)
	end,
	draw=function(this)
		sspr(0,32,8,16,this.x,this.y)
		sspr(0,32,8,16,this.x+8,this.y,8,16,true,true)
	end
}

function init_fruit(this,ox,oy)
	sfx_timer=20
	sfx"16"
	init_object(fruit,this.x+ox,this.y+oy,26).id=this.id
	destroy_object(this)
end


platform={
	init=function(this)
		this.x-=4
		this.hitbox.w=16
		this.dir=this.spr==11 and -1 or 1
		this.semisolid_obj=true
		
		this.layer=2
	end,
	update=function(this)
		this.spd.x=this.dir*0.65
		-- screenwrap
		if this.x<-16 then
			this.x=lvl_pw
		elseif this.x>lvl_pw then
			this.x=-16
		end
	end,
	draw=function(this)
		spr(11,this.x,this.y-1,2,1)
	end
}

message={
	init=function(this)
		this.text="-- celeste mountain --#this memorial to those#perished on the climb"
		this.hitbox.x+=4
		this.layer=4
	end,
	draw=function(this)
		if this.player_here() then
			for i,s in ipairs(split(this.text,"#")) do
				camera()
				rectfill(7,7*i,120,7*i+6,7)
				?s,64-#s*2,7*i+1,0
				camera(draw_x,draw_y)
			end
		end
	end
}

big_chest={
	init=function(this)
		this.state=max_djump>1 and 2 or 0
		this.hitbox.w=16
	end,
	update=function(this)
		if this.state==0 then
			local hit=this.check(player,0,8)
			if hit and hit.is_solid(0,1) then
				music(-1,500,7)
				sfx"37"
				pause_player=true
				hit.spd=vector(0,0)
				this.state=1
				this.init_smoke()
				this.init_smoke(8)
				this.timer=60
				this.particles={}
			end
		elseif this.state==1 then
			this.timer-=1
			flash_bg=true
			if this.timer<=45 and #this.particles<50 then
				add(this.particles,{
					x=1+rnd"14",
					y=0,
					h=32+rnd"32",
				spd=8+rnd"8"})
			end
			if this.timer<0 then
				this.state=2
				this.particles={}
				flash_bg,bg_col,cloud_col=false,2,14
				init_object(orb,this.x+4,this.y+4,102)
				pause_player=false
			end
		end
	end,
	draw=function(this)
		if this.state==0 then
			draw_obj_sprite(this)
			spr(96,this.x+8,this.y,1,1,true)
		elseif this.state==1 then
			foreach(this.particles,function(p)
				p.y+=p.spd
				line(this.x+p.x,this.y+8-p.y,this.x+p.x,min(this.y+8-p.y+p.h,this.y+8),7)
			end)
		end
		spr(112,this.x,this.y+8)
		spr(112,this.x+8,this.y+8,1,1,true)
	end
}

orb={
	init=function(this)
		this.spd.y=-4
	end,
	update=function(this)
		this.spd.y=appr(this.spd.y,0,0.5)
		local hit=this.player_here()
		if this.spd.y==0 and hit then
			music_timer=45
			sfx"51"
			freeze=10
			destroy_object(this)
			max_djump=2
			hit.djump=2
		end
	end,
	draw=function(this)
		draw_obj_sprite(this)
		for i=0,0.875,0.125 do
			circfill(this.x+4+cos(frames/30+i)*8,this.y+4+sin(frames/30+i)*8,1,7)
		end
	end
}

flag={
	init=function(this)
		this.x+=5
	end,
	update=function(this)
		if not this.show and this.player_here() then
			sfx"55"
			sfx_timer,this.show,time_ticking=30,true,false
		end
	end,
	draw=function(this)
		spr(118+frames/5%3,this.x,this.y)
		if this.show then
			camera()
			rectfill(32,2,96,31,0)
			spr(26,55,6)
			?"x"..two_digit_str(fruit_count),64,9,7
			draw_time(43,16)
			?"deaths:"..two_digit_str(deaths),48,24,7
			camera(draw_x,draw_y)
		end
	end
}

-- [object class]

function init_object(type,x,y,tile)
	-- generate and check berry id
	local id=x..":"..y..":"..lvl_id
	if type.is_fruit and collected[id] then
		return
	end

	local obj={
		type=type,
		collideable=true,
		-- collides=false,
		spr=tile,
		flip=vector(),
		x=x,
		y=y,
		hitbox=rectangle(0,0,8,8),
		spd=vector(0,0),
		rem=vector(0,0),
		layer=0,
		id=id,
	}

	function obj.left() return obj.x+obj.hitbox.x end
	function obj.right() return obj.left()+obj.hitbox.w-1 end
	function obj.top() return obj.y+obj.hitbox.y end
	function obj.bottom() return obj.top()+obj.hitbox.h-1 end

	function obj.is_solid(ox,oy)
		for o in all(objects) do
			if o!=obj and (o.solid_obj or o.semisolid_obj and not obj.objcollide(o,ox,0) and oy>0) and obj.objcollide(o,ox,oy) then
				return true
			end
		end
		return oy>0 and not obj.is_flag(ox,0,3) and obj.is_flag(ox,oy,3) or -- jumpthrough or
		obj.is_flag(ox,oy,0) -- solid terrain
	end

	function obj.is_ice(ox,oy)
		return obj.is_flag(ox,oy,4)
	end

	function obj.is_flag(ox,oy,flag)
		for i=max(0,(obj.left()+ox)\8),min(lvl_w-1,(obj.right()+ox)/8) do
			for j=max(0,(obj.top()+oy)\8),min(lvl_h-1,(obj.bottom()+oy)/8) do
				if fget(tile_at(i,j),flag) then
					return true
				end
			end
		end
	end

	function obj.objcollide(other,ox,oy)
		return other.collideable and
		other.right()>=obj.left()+ox and
		other.bottom()>=obj.top()+oy and
		other.left()<=obj.right()+ox and
		other.top()<=obj.bottom()+oy
	end

	-- returns first object of type colliding with obj
	function obj.check(type,ox,oy)
		for other in all(objects) do
			if other and other.type==type and other~=obj and obj.objcollide(other,ox,oy) then
				return other
			end
		end
	end
	
	-- returns all objects of type colliding with obj
	function obj.check_all(type,ox,oy)
		local tbl={}
		for other in all(objects) do
			if other and other.type==type and other~=obj and obj.objcollide(other,ox,oy) then
				add(tbl,other)
			end
		end
		
		if #tbl>0 then return tbl end
	end

	function obj.player_here()
		return obj.check(player,0,0)
	end

	function obj.move(ox,oy,start)
		for axis in all{"x","y"} do
			obj.rem[axis]+=axis=="x" and ox or oy
			local amt=round(obj.rem[axis])
			obj.rem[axis]-=amt
			local upmoving=axis=="y" and amt<0
			local riding=not obj.player_here() and obj.check(player,0,upmoving and amt or -1)
			local movamt
			if obj.collides then
				local step=sign(amt)
				local d=axis=="x" and step or 0
				local p=obj[axis]
				for i=start,abs(amt) do
					if not obj.is_solid(d,step-d) then
						obj[axis]+=step
					else
						obj.spd[axis],obj.rem[axis]=0,0
						break
					end
				end
				movamt=obj[axis]-p -- save how many px moved to use later for solids
			else
				movamt=amt
				if (obj.solid_obj or obj.semisolid_obj) and upmoving and riding then
					movamt+=obj.top()-riding.bottom()-1
					local hamt=round(riding.spd.y+riding.rem.y)
					hamt+=sign(hamt)
					if movamt<hamt then
						riding.spd.y=max(riding.spd.y,0)
					else
						movamt=0
					end
				end
				obj[axis]+=amt
			end
			if (obj.solid_obj or obj.semisolid_obj) and obj.collideable then
				obj.collideable=false
				local hit=obj.player_here()
				if hit and obj.solid_obj then
					hit.move(axis=="x" and (amt>0 and obj.right()+1-hit.left() or amt<0 and obj.left()-hit.right()-1) or 0,
									axis=="y" and (amt>0 and obj.bottom()+1-hit.top() or amt<0 and obj.top()-hit.bottom()-1) or 0,
									1)
					if obj.player_here() then
						kill_player(hit)
					end
				elseif riding then
					riding.move(axis=="x" and movamt or 0, axis=="y" and movamt or 0,1)
				end
				obj.collideable=true
			end
		end
	end

	function obj.init_smoke(ox,oy)
		init_object(smoke,obj.x+(ox or 0),obj.y+(oy or 0),29)
	end

	add(objects,obj);

	(obj.type.init or stat)(obj)

	return obj
end

function destroy_object(obj)
	del(objects,obj)
end

function move_camera(obj)
	cam_spdx=cam_gain*(4+obj.x-cam_x)
	cam_spdy=cam_gain*(4+obj.y-cam_y)

	cam_x+=cam_spdx
	cam_y+=cam_spdy

	-- clamp camera to level boundaries
	local clamped=mid(cam_x,64,lvl_pw-64)
	if cam_x~=clamped then
		cam_spdx=0
		cam_x=clamped
	end
	clamped=mid(cam_y,64,lvl_ph-64)
	if cam_y~=clamped then
		cam_spdy=0
		cam_y=clamped
	end
end

function draw_object(obj)
	(obj.type.draw or draw_obj_sprite)(obj)
end

function draw_obj_sprite(obj)
	spr(obj.spr,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
end
-->8
-- [level loading]

function next_level()
	local next_lvl=lvl_id+1

	-- check for music trigger
	if music_switches[next_lvl] then
		music(music_switches[next_lvl],500,7)
	end

	load_level(next_lvl)
end

function load_level(id)
	has_dashed,has_key= false

	-- remove existing objects
	foreach(objects,destroy_object)

	-- reset camera speed
	cam_spdx,cam_spdy=0,0

	local diff_level=lvl_id~=id

	-- set level index
	lvl_id=id

	-- set level globals
	local tbl=split(levels[lvl_id])
	for i=1,4 do
		_ENV[split"lvl_x,lvl_y,lvl_w,lvl_h"[i]]=tbl[i]*16
	end
	lvl_title=tbl[5]
	lvl_pw,lvl_ph=lvl_w*8,lvl_h*8

	-- level title setup
	ui_timer=5

	-- reload map
	if diff_level then
		reload()
		-- check for mapdata strings
		if mapdata[lvl_id] then
			replace_mapdata(lvl_x,lvl_y,lvl_w,lvl_h,mapdata[lvl_id])
		end
	end

	-- entities
	for tx=0,lvl_w-1 do
		for ty=0,lvl_h-1 do
			local tile=tile_at(tx,ty)
			if tiles[tile] then
				init_object(tiles[tile],tx*8,ty*8,tile)
			end
		end
	end
end

-- replace mapdata with hex
function replace_mapdata(x,y,w,h,data)
	for i=1,#data,2 do
		mset(x+i\2%w,y+i\2\w,"0x"..sub(data,i,i+1))
	end
end
-->8
-- [metadata]

--@begin
-- level table
-- "x,y,w,h,title"
levels={
  "0,0,1,1,cave entrance",
  "0,0,2,1,lost trail",
  "0,0,1,1,0m",
  "0,1,2,1,100 m",
  "0,0,2,2,25 m",
  "0,0,1,2,325 m",
  "0,0,1,1,500 m",
  "1,0,1,2,600 m",
  "0,1,2,1,450 m",
  "0,1,1,1,480 m",
  "0,0,2,1,550 m",
  "0,1,2.0625,1,???",
  "1.0625,0,1,2,fall",
  "0,1,1,1,",
  "0,0,1,1,",
  "0,0,1,1,",
  "0,0,1,2,ascent"
}

-- mapdata string table
-- assigned levels will load from here instead of the map
mapdata={
  "31323324252533757575242525263125392a29313233757575212525252536242a003910293a087534252525253321250a392a1900293a193931323233212525392a000000002910102a29103a3132252a0000001a00000019000029101010310000000000000000000000000000291000000000000000000000000000000019000000000000000000000000000000000000000000000000000000000e0f757500000000000000000000000000392775000000000000000000000000002125220000000000090000000000093831322555000100392a00000900381021222331727343442a090038103910753125482253535353734421222223757575242525",
  "75752024252532337575753148252525332426757575313232323331252548257527203132332a29103a75753125253321252536753910101010103a3132323222253536102a00000029103a083133212548261010102a00002910103a29103a2533392a0000000000001929103a27312525332a0000000000001929103a291033102a0000000000000000000029242324332b000000000000000000002910102a190000000000000000000000392426372b00000000110000000000000019290000000000000000000000000029243310000000003b27000000000027757575000000000000000000000000000037752a000000003b31353535362148237534000100000000000000000000000010750000000000002910103a343232267575222222223536000000000000000029750000000000000000291010101031367525483233190000000000000000000019000000000000000000000000191b757532332a0000000000000000000000000000000000090000383a000000003b7521222311111100000000000000000000000000000020757521362b00000011342525252222361111110000000000000017000000003b3422332b00001111212331252525262123757511111100000000450000000000113011001a11212225252325254826314822232122232800000057000000003b2125232b3b212525254826",
  "2526392a3132324833313232322525254826100000293a30004500293a24252525262a00000029370047000810312548253317000000007500570000293a31253375470009000010001700000810752475105700293a38103a000000002975242a390a003910102a292800000011212500100038102a000000293a003b213232391010102a00393a0000103a11372122102a29100000292a00392a29212225252a0000293a00000039100017242548250000000029103a09102a00463125253200010000000029102a00003910313321757520390a0017000000381010102148223629100a004700093910102a1931253300392a000057381010102a00090831",
  "32323232252525252525252525262425253324252525332122222223312525251010103a313232323232323232332425332132323233212548252525232425250029102a1b1b102a19291010103448333433103a08343232322525252631254800001900000000000000111121233700002910103a392a470031252525232425000000111111000000002122323300000000192910100a5700002448252631250001007575270000001131263a4500000009007575752b173b21252525252324237575753433000039212337101a00000010007575272b003b31323232323324252235360a00000810242629103a000008103a2775302b003a1b1b1b1b1b1b2432332710000000081024332122360a000029102422332b10100a000000000024212226100000000029372148332a00000016293133272b002a11110000001124242533102800000000003133100000000000003b21262b003b21232b003b21252426102910000000000019292a0000000000003b24262b003b24262b003b313231331000103a000000000000000000000000003b24262b093b2426000000293a231010002910280000000000000017000000001124262b103b2426000000081026102a000010100000170000000045000000002731262b103b24260000000029261000090029103a00470000000057000000003136302b103b24482222222222",
  "25252525252525252525252525252525332432323331323331323232323225252525252525252525252525252525252621262b08103a392a000029103a2024482525252525252525252525252525253324262b002910100000000000193b31252525252525252525252525252532332125262b0000102a0000000000003b27312525252525252532323232323329102448262b000010000017000000003b31352525252525253321222236471900102425262b00001900111111111100000039252532322533212525262a46000029313226110016003b34222222232b39102a2533094537343225482609003f007529202423110000001b31324833212223202610105729107531322523212375757510313223110000001b20373432323235262a1900097575757524332448367575755529312311000000190029103a29752536473821237575212621252620342222222223312311000000000810103a75332122224832353532333132323536313232323236313611110000001929107575313232331b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b34360d0e0e0f757575751b1b0000000000003a0016003a0000000000000000392a290a00003921751b1b0000000000000010100a0010100a00000000000000083a392a003910241b000000000000170000002a0000002a00001700000000000029100a0810102400000810100011111111111111111111111111111111111175752a0038102a2400003910103b34353535353620343535353535363435353536757575102a39241100102a19001b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b75757575270d0f24752b0000000000000808000000000000000000000000083a1075752133100a3123110000000017000000000000000008080000000000002910753426102a002048201100000000000000000017000000000000170000000810752737101a002125332011111111111111111111111111111111111100000010753010100000243321223535353634353535353522223634353535362b000010212610100000243532331b1b1b1b1b1b1b1b1b1b37271b1b1b1b1b1b000000292426102a00002439102a0000000000000000000821332b00000000000000000024261000003b24102a000000000000000000003930202b00000000000000000024332a00003b31100a0000000000000000000029372b0000160000003a00170037100000003b272a010000001700000900170000190000000000000010004500202a000009113075750000004500391000450000000900000000000910004700000000381021262375202700470010103a57000038103a00000039101000570009391010102433482321252357391010104509381010101000001010103a453810101010103027",
  "252525252525323232323232323232252525323232331b1b451b1b1b1b1b3b2425261b1b1b1b000047000a000a003b2425330000000000001700000000003b2426000029001111111111110000003b2426111111113435352235231100003b24260000160810103a3720242311003b31333a000000192910103a31262009392a10100a00000000102910103123102a3910103a000911001900102910312339102910101010272b00001000192930102a7575757534332b000019000000377575752b1b1b1b1b00000000000011757520232b0000000000000000000075757575332b16000a000a000000000075752122202b00001111000000001111212232322300003b34362b17173b202132332122260000091b1b1b1b1b1b34332122252533000810103a000009001b1b242532321b00001929101010100a0939313321225817000039102a00190810101b2125253a00000810100016000029103a31252510000008102a393a0000391010272425103a00002910102a000810102a30312510100a00000019000000101011313624102a0000000000000039102a2734232410103a00000000000810100a242330311010100a00010000391010113133313610103422233422222236107575757575291010312523312533392a27757575210029101031332030102a21252375212500002910103a21262a21252525222525",
  "31252548253310103a2448252631252520313232333a291021323232323631481b1b1b1b1b293a75371b1b1b1b1b1b313a160000000029751b0000090000003b293a09111175751b00393a19393a003b0010103435361b0008102a1129100a3b39102a1b1b1b0000161911751119003b2a0000000000080000117575272b163b000000170000000011213535332b003b111111111111111121331b1b1b0009392235353535353535331b000009391010331b1b1b1b1b1b1b1b0000391010102a00000000000900000000082a757575750001000039103a0900003b212236752122222236101010103a003b2426757524482526291010101010283b2426752125",
  "323321222311291010103a003910242500003132252300192910103a101131250000460031330000001010102a212331000000001b1b000009291010002425220000000011110008101010100024252500010000212311002910102a00242525757521222525232b0010100a11244825752731252548262b0010190021252525222523313232332b0010103a24252525252532361b1b1b00001929113125253225331b1b000000000000003423313321261b0000000000110000007524222232332b0000000011272b00007524253321232b0016003b21262b00007531332125262b390a003b24262b003b2122222525262b103a003b31261111112425252525261010100a003b312222362425482525261129100000003b313334322525252525232b19000000001b1b1b1b3125252548262b000000000000391010102425252526111111111111757575102a3132253125233422222222237520100a472731233132363132323233102a19005724222536391010102a000000000000002425263910102a000000160000000000244833102a0000001111111111111111312539100000000034353535353522223624102a0000000000450057000031333432100000000000004600000000000039102a0000000000000000000000391010101717000000000000003910101010101047450000000039101010102122222222",
  "32323232323233212222222533242525482533313232323232323232333132320029101010103a31322548262125253232333910101010102a0029102a47103a00000029101010103a242526312526391010102a0000000000000019005710100001000000291010212532331b243310102a19000000000000110000000029102222360000392122253300453b3075102a0000000000000011271109393a00292526000000273125330000473b37752a00000000160000393425231010102865253300000024233700000057001b750000000000000039103a31322222222235262b0000002433000000000000001b00090900000000101010103a3132253321261100000030000000001111000000082a293a0000391010101010101037212525232b003b300000003b2775000000083a00290a0010101010102a0000462425252600003b301700003b307516000000293a390a391010102a19000000003125253300003b370000003b307500000000001919001010102a00000000000011243327110000470000003b2436110000000000003910102a0000000011111121252226750900460000003b3721231111111100081010103a001111112122222525252675103a000000001121252536212223111139101010112122233125254825252675101010103a3b212525262125252522231010102a212548252324252525",
  "1b1b291010101010102a000000093910000011192910102a0000090039101010003b27006529100a00391010101010103a3b2436212235353522362122233423103b303432331b1b1b37343232252337103b371b1b1b0000001b1b1b3b242522103a750900000011002a00003b2448251010102a1600112711002a003b24323229102a0011112126751100003b3721227575111121353226757516003b2125257534353533291031362a00003b24254836102a0057002910103a00003b242532101001000000003910100a003b243321367575752136391010103a003b372125757575343310101010101010102a24252375272910101010101010102a002425",
  "32323225252525252624254825323233392a3b302b103132252548252525267539101031323248253324323233391010100a3b302b10103a3125252525483375101010102a003133213310101010102a19003b302b1010101031252525267575102a000000000000302b00292a00190000003b302b29101010103132323321221000160000000000301117000000000000003b302b00102a1010342222222525100000001100000024232b000000001100003b302b00100029100024252548252a000000272b000031262b0009003b272b003b302b00191100103a312525252500000000302b00003b372b39103a3b302b003b302b003b272b2910103125253200000000302b00003b75000010003b302b163b302b163b302b0010103a31334700000000372b00003b75000010003b302b003b302b003b302b001010102a0045000100001b0011000045000000003b302b003b372b003b302b0029101000005775757527110075000047000000003b302b00001b00003b302b0000102a00003a75752125231175000017000000003b302b00000000163b302b0000100000001023752448332775110000000000003b302b00001100003b302b00002a0875757525223233212522231111110000003b302b003b272b003b302b0000003910752132332122252548252222232b00003b302b003b302b003b302b391010102a2125",
  "252525253324252525252525252533242525252526242525252525482525253232254825262125254825323232323334323232323233313232323225252532332122252525263132323233000029101010101010102a0000000000003132332122252532323233000000004700000029101010102a000000000000000045000024254825000000000000000057000000001010101000000000000000000047000031252525000000000000000000000000002910102a0000000000390000004600000024253200000000000000000000000000001010000000000000100000000000000031334200000000000000000000000000002910000000000000103a0000000000000042530000000000000000000000000000002a00000000000010103a0000000000005253000100000000000000000000000000000000000000001010100000000000006253222223000000550000000000000000000000000000391010103a0000000000475248252536212222222222230000650000000000000010101010103a0000000057622532332125252525252525353642440000000000391010101010103a090000002126212225254825252525264243535344000009391010101010101010103a003924262425252525252525253352535353540039101010101010101010101010102125262425252525252525264253535353534410101010101010101010101010102448",
  "2525252526000001000024252525482525252525260000000000313232322525252548252600000000004243434431322525252526000000000062635353434325252525260000000000002762635353322525252600000000000024222362632331322526000000000000242525222225222331330000000000003125252525252525230000000000000000244825252525252600000000000000002425253225252526000000000000000024323321252525330000000000000000372122252525260000000000000000002125252525252600000000390a00000024252525252526000000081000000000242525252548260000000010000000003125252532252600000000103a000000002425254431260000000010100000000024254853443000000000101000000000242525535437000000001010000000002425255353440000000010103a00000024253253535400000000101010000000243342535364000000001010100000003042535354000000003910101000000037525353540000003910101010000000005253535400000810101010103a000000525353540000391010101010100a0000525353640039101010101010103a00006253542700101010101010101010103a005254373910101010101010101010103a525439101010101010101010101010105254101010101010101010101010101052",
  "00000000000000000000000000000000757575343535353535353535230000007575271b1b1b1b1b1b1b1b3b2500000027751b00000000000000003b3000000024221713000011110000003b3000000024251100003b21232b000011300d0e0f3125262b003b24262b183b21252b003b3b24262b003b24262b003b31322b163b3b24262b003b24262b000000000000001124262b003b24262b000000000000002125262b003b24262b000011110000003232332b183b31262b003b343600000000000000000000300000000000111111000000000000003000000000002122220001000000000030000000000024252522222222222222260000000000242525",
  "63535353535353535354000000081052446263535353636363640000000029625343446263643910102a000000000010535364391010102a0000000000000019536410102a000000000000000000003954102a1900000000000000000018001064100a000000000000000000000039101019000000000000000000000008101010000000000000000000000000391010103a000000000000000000000810102a29100a000000000000000000004243434410000000000000000000000062635353443a01000000000000550042434362534243434428450000424343636363435352535364424343446263642a472962425353544253535353442a0000460019",
  "54000000000000000000000000000052540000000000000000000000000000525400000000000000000000000000005254000000000000000000000000000052540000000000000000000000000000525400000000000000000000000000005254000000000000000000000000000052540000180000000000000000000000525400000000000000000000000000005254000000000000000000000000131752540000000000000000000000000046525400000000000000000000000000005254000000000000000000000000000052540000000000000000000000000000525343440000010000000000000000005253535343434343440000000000000052",
  "5353536439102a00000000003b2425255353544610100a00000000003b24252553636439102a0000000000163b3125485420082a10000000000000000075312564581713290a00000000000000754243232010102a000000000000003b425353262b29100000000000390a0011525364262b0010000000001610001127626421262b00190011000908103b2133004731332b00003b2708103a103b3000005742750000003b30081010103b30001a0052750000003b302b10102a3b3000000052750000003b302b29100a3b3000000052232b00163b372b39100a3b302b3b425325362b00001b0029103a3b372b3b625326750000000900081010001b00003b523375000008103a0029103a0000003b6222232b1109292a111111190000003b2125252236103a552122232b0000163b24482533424343442425332b0000003b2425264253535354243375000000003b2432265253536364377575000000003b242337626364212223752b083a00003b242522233921252532362b001000003b312548261031253342442b0010000000753225261010304253642b001000000075443133102a3752542b00391000163b75534439100a4253542b00101000003b425354102a006253542b0810103a003b5263641000004552542b001010100a3b522339100a004652542b39101010013b5226102a00000052542b10102a29424353"
}

-- list of music switch triggers
-- assigned levels will start the tracks set here
music_switches={
	[2]=20,
	[3]=30
}

--@end

-- tiles stack
-- assigned objects will spawn from tiles set here
tiles={}
foreach(split([[
1,player_spawn
8,key
11,platform
12,platform
18,spring
19,spring
20,chest
22,balloon
23,fall_floor
24,overgrown_balloon
26,fruit
45,fly_fruit
64,fake_wall
86,message
96,big_chest
118,flag
]],"\n"),function(t)
 local tile,obj=unpack(split(t))
 tiles[tile]=_ENV[obj]
end)

--[[

short on tokens?
everything below this comment
is just for grabbing data
rather than loading it
and can be safely removed!

--]]

-- copy mapdata string to clipboard
function get_mapdata(x,y,w,h)
	local reserve=""
	for i=0,w*h-1 do
		reserve..=num2hex(mget(x+i%w,y+i\w))
	end
	printh(reserve,"@clip")
end

-- convert mapdata to memory data
function num2hex(v)
	return sub(tostr(v,true),5,6)
end
__gfx__
00000000000000000000000009999990000000000000000000000000000000000000000500000000500000000007707770077700494949494949494949494949
00000000099999900999999099999999099999900999990000000000099999900000005500000000550000000777777677777770222222222222222222222222
000000009999999999999999999ffff999999999999999900999999099f1ff190000055500000000555000007766666667767777000420000000000000024000
00000000999ffff9999ffff999f1ff19999ffff99ffff9909999999999fffff90000555500000000555500007677766676666677004200000000000000002400
0000000099f1ff1999f1ff1909fffff099f1ff1991ff1f90999ffff999fffff90000555500055000555500000000000000000000042000000000000000000240
0000000009fffff009fffff00033330009fffff00fffff9099fffff9093333900000055500555500555000000000000000000000420000000000000000000024
00000000003333000033330007000070073333000033337009f1ff10003333000000005505555550550000000000000000000000200000000000000000000002
00000000007007000070007000000000000007000000700007733370007007000000000555555555500000000000000000000000000000000000000000000000
555555550000000000000000000000000000000000000000009999000554553000211100555555550300b0b06665666500000000000000000000000070000000
55555555000000000000000000003b00000000000000000009a99990577366240132413205555550003b33006765676500000000007700000770070007000007
5555555500000000000000000003333000000000000000000a7a99903766664503b1424000555500028888206770677000000000007770700777000000000000
5555555500700070003b3300000b333f000000000000000009a99990246664654231141000055000089888800700070000000000077777700770000000000000
5555555500700070033333b0000333bf000000000000000009999990564666d50341243000000000088889800700070000000000077777700000700000000000
55555555067706770333b3300003b330000000000000000009999990466634d50114411200000000088988800000000000000000077777700000077000000000
555555555676567600b33300000033000000000000000000009999000436d2200012140000000000028888200000000000000000070777000007077007000070
5555555556665666000ff00000000000000000000000000000000000002554000030002000000000002882000000000000000000000000007000000000000000
5666666556666666666666666666666567dddddddddddddddddddd76566666655000000055555555555555555500000007777770000000000000000000000000
66777766667777777777777777777766677dddddddddddddddddd776667777665000000005555555555555506670000077777777000777770000000000000000
677d77766777ddddd777777ddddd7776677dddddddddddddddddd776677777765500000000555555555555006777700077777777007766700000000000000000
67dddd76677dddddddd77dddddddd7766777dddddddddddddddd7776677dd7765500000000055555555550006660000077773377076777000000000000000000
67dddd7667dddddddddddddddddddd766777dddddddddddddddd777667dddd765500000000005555555500005500000077773377077660000777770000000000
677dd77667dd77ddddddddddddd7dd76677dddddddddddddddddd77667dddd765550000000000555555000006670000073773337077770000777767007700000
6677776667dd77dddddddddddddddd76677dddddddddddddddddd77667d7dd76555555000000005555000000677770007333bb37070000000700007707777770
5666666567dddddddddddddddddddd7667dddddddddddddddddddd7667dddd76555555550000000550000000666000000333bb30000000000000000000077777
67dddd7667dddddddddddddddddddd76566666666666666666666665677ddd760000000500000005500000000000066603333330020420400000000000000000
677ddd7667dddddddddddddddddddd76667777777777777777777766677dd7760000000500000055550000000007777603b33330040400400088088000000030
677ddd7667dd7dddddddddddd77ddd766777ddd7777777777ddd7776677dd7760000005500000555555000000000076603333330030403400088888030000400
67ddd77667ddddddddddddddd77ddd76677ddddd7d7777ddddddd77667ddd776000000550000555555550000000000550333b330040400200088288040030020
67ddd776677dddddddd77dddddddd776677ddddddd7777d7ddddd77667dddd760000005500055555555550000000066600333300000204000008880043002043
677dd7766777ddddd777777ddddd77766777ddd7777777777ddd777667dddd760000055500555555555555000007777600044000003403000000800002004302
677dd776667777777777777777777766667777777777777777777766667dd7660055555505555555555555500000076600044000000400000000300004040004
67dddd76566666666666666666666665566666666666666666666665566666655555555555555555555555550000005500999900000300000000300000420040
00000000000000005bbbbbbbbbbbbbbbbbbbbbb5044400040340040000004000dddddddd00000000000000000000000000000000000000000000000000000000
0000000000000000bb33333333333333333333bb000240300023440003004000d77ddddd00000000000000000000000000000000000000000000000000000000
0000000000000000b3331111133333311111333b000003200000244000432000d77dd7dd00000000000000000000000000000000000000000000000000000000
0000000000000000b3311111111331111111133b030004000000002400040000dddddddd00000000000000000000000000007000000000000000000000000000
0000000000000000b3111111111111111111113b004404000000034034044300dddddddd00000000000000000000000000070700000000000000000000000000
0000000000000000b3113311111111111113113b000232000000420002440000dd7ddddd0000000000000000000000000070a060000000000000000000000000
0000000000000000b3113311111111111111113b000040000000300000044000ddddd7dd000000000000000000000000070a7906000000000000000000000000
0000000000000000b3111111111111111111113b000042000000000000002400dddddddd000000000000000000000000d0009006000000000000000000000000
0000000000000000b3111111111111111111113b0000000000088000000440000000000000000000000000000000000000000000000000000000000000000000
0000000000000000b3311111111111111111133b00000000000880000032000043000000000000000000000000000000000777d0000000000000000000000000
0000000000000000b3311111111111111111133b0000000000088000000440000020243000000000000000007700003b00776dd0007770000000000000000000
0000000000000000b3331111111111111111333b000000300008800000004300000400440000000000000000770000b7007700000377dd000000000000000000
0000000000000000b3331111111111111111333b003204300008800000044200004000000000000000077000770000760076db0007b0ddd03770000000000000
0000000000000000b3311111111111111111133b0004420000000000000200000304024000000000007776007760077d007d350007d00db00b3b007700000000
0000000000000000b3311111111111111111133b004203400008800000340000420030040077770000777d0006db06d0006db0000b30d3000773007d00777d00
0000000000000000b3111111111111111111113b043000240008800000400000000000000777777007700dd0b3333bd000d3000007d3d30007dd307d07773300
0000000000000000b3111111111111111111113b00000000007777000000000000000000077007700770b3db3bddbd0000bddd5006d0ddd00b3ddb33b7b30000
00aaaaaa00000000b3111111111111111111113b3030000007000070000000000000000003600000077d3b3303ddd5000033555003b00d5006d3ddbd336d3000
0a99999900000000b3113111111111111331113b040003007077000700000000000000000b30000006ddd3dd00355000000b30000b5005500bd003d3b036bd00
a99aaaaa00000000b3111111111111111331113b040340007077bb07000000000000000006d000007dd00bd500b00000077377003300000003b00bd500003dd0
a9aaaaaa00000000b3311111111331111111133b02404403700bb30700000000000000000dd033d07d0000550030000077b3dd73b30000000d5000d507700dd0
a999999900000000b3331111133333311111333b30430240700b330700000000000000000333bd50d500000000b000077330356730b000000000005506b3dd50
a999999900000000bb33333333333333333333bb042004000700007000000000000000000035550000000000000000076300b03b003000000000000000033500
a9999999000000005bbbbbbbbbbbbbbbbbbbbbb50400240000777700000000000000000000b0000000000000000000000b0000dd00000000000000000000b000
aaaaaaaa00000000b42bb42b44bbbb441412114166666166004bbb00004b000000400bbb00000000d00000000000000000000773000000000000007000003000
a49494a10000000034433343324333231911414166555165004bbbbb004bb000004bbb330000000d00000000000000000000bd3b0000000000000060070b0000
a494a4a1000000001342342113423441111191211111111104200333042bbbb3042b3300000000d0000000000000000000077b3000000000000000d0d0700000
a49444aa0000000014433411111441311112111166166665040000000400b3300400000000000d00000000000000000000753030000000000000000d00060000
a49999aa000000003212141111421111111411115516555504000000040000000400000000000d000000000000000000076500b00000000000000000000d0000
a4944499000000001114124111311111111111111111111142000000420000004200000000000d000000000000000000db30000070000000000000000000d000
a494a444000000001141114311111111111111116665516540000000400000004000000000000000000000000000000765533777600000000000000000000000
a49499990000000011311111111111111111111155555155400000004000000040000000000d0000000000000000000d5555bb560000000000000000000000d0
__label__
cccccccccccccccccccccccccccccccccccccc775500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccccccccc776670000000000000000000000000070000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccccccc77ccc776777711111111111111110000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccccccc77ccc776661111111111111111110000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccccccccccc7775511111111111111111110000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccccccc77776671111111111111111110000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccc77cccccccccc777777776777711111111111111110000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccc77cccccccccc777777756661111111111111111110000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccc77555555551111111111111111111110000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccc777555555500000000000000000000000000000000000000000000000000000000000000000000000000000007000000000
ccccccccccccccccccccccccccccc777555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccc7777555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccc7777555500000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000
ccccccccccccccccccccccccccccc777555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccc777550000000300b0b000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccc6cccccccccc7750000000003b330000000000000000000000000000000000000000000007000000000000000000000000000000000000
cccccccccccccccccccccccccccccc77000000000288882000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccc77000000700898888000000000000000000000000000000111111111111111111111111111111111111111111111110000
ccccccccccccccccccccccccc77ccc77000000000888898000000000000000000000000000000111111111111111111111111111111111111111111111110000
ccccccccccccccccccccccccc77ccc77070000000889888000000000000000000000000000000111111111111111111111111111111111111111111111110000
ccccccccccccccccccc77cccccccc777000000000288882000000000000000000000000000000111111111111111111111111111111111111111111111110000
ccccccccccccccccc777777ccccc7777000000000028820000000000000000000000000000000111111111111111111111111111117111111111111111110000
cccccccccccccccc7777777777777777000000000000000000000000000000000000000000000111111111111111111111111111111111111111111111110000
cccccccccccccccc7777777777777775000000000000000000000000000000000000000000000111111111111111111111111111111111111111111111110000
cccccccccccccc775777777566656665000006000000000000000000000000000000000000000111111111111111111111111111111111111111111111110000
ccccccc66cccc7777777777767656765000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccc66cccc777777c777767706770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccc777777cccc7707000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccc777777cccc7707000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccc777777cc77700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccc7777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccc775777777500000000000000000000000000000000000000000000000000111111111111111111111111111111111111111111111111111111
cccccccccccccc776665666700000000000000000000000000000000000000000000000000111111111111111111111111111111111771111111111111111111
ccccccccccccc7776766676500000000000000000000000000000000000000000000000000111111111111111111111111111111111771111111111111111111
ccccccccccccc7776770677000000000000000000000000000000000000000000000000000111111111111111111111111111111111111111111111111111111
cccccccccccc77770700070000000000000000000000000000000000000000000000000000111111111111111111111111111111111111111111111111111111
cccccccccccc77770700070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccc770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccc770000000000000000000000000000000000000000001111111111111111111111111111111111110000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000000000000000001111111111111111111111111111111111110000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000000000000000001111111111111111111111111111111111110000000000000000000000000000000000
cccccccccccc77770000000000000000000000000000000000000000001111111111111111111111111111111111110000000000000000000000000000000000
cccccccccccc77770000000000000000000000000000000000000000001111111111111111111111111111111111110000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000000000000000001111111111111111111111111111111111110000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000111111111111111111111111111111111111111111111111110000000000000000000000000000000000
cccccccccccccc770000000000000000000000000000111111111111111111111111111111111111611111111111110000000000000000000000000000000000
cccccccccccccc770000000000000000000000000000111111111111111111111111111111111111111111111111110000000000000000000000000000000000
cccccccccccccc770000000000000000000000000000111111111111111111111111111111111111111111111111110000000000000000000000000000000000
ccccccccc77ccc770000000000000000000000000000111111111111111111111111111111111111111111111110000000000000000000000000000000000000
ccccccccc77ccc770000000000000000000000000000111111111111111111111111111111111111111111111110000000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000111111111111111111111111111111111111111111111110000000000000000000000000000000000000
cccccccccccc77770000000000000000000000000000111111111111111111111111111111111111111111111110000000000000000000000000000000000000
cccccccc777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccc777777750000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccc77551111111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000
cccccc77667111111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000
c77ccc77677771111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000600000000000000
c77ccc77666111111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000
ccccc777551111111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000
cccc7777667111111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000
77777777677771000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777775666111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555511111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
51555555551111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55551155555111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55551155555511111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555551111000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55155555555555111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555500000000000000000000000000000000000000000000000000000000001111111111111111111114999999449999994499999941110000000000000
55555555550000000000000000000000000000000000000000000000000000000001111111111111111411119111111991111119911111191111100000000000
55555555555000000000000000000000000000006000000000000000000000000001111111111111111951519111111991111119911111191111100000000000
55555555555500000000000000000000000000000000000000000000000000000001111111111111111915159111111991111119911111191111100000000000
55555555555550000000000000000000000000000000000000000000000000000001111111111111111915159111111991111119911111191111100000000000
55555555555555000000000000000000000000000000000000000000000000000001111111111111111951519111111991111119911111191111100000000000
55555555555555500000000000000000000000000000000000000000000000000001111111111111111411119111111991111119911111191111100000000000
55555555555555550000000000000000000000000000000000000000000000000001111111111111111111114999999449999994499999941111100000000000
55555555555555555555555500000000077777700000000000000000000000000000000000000111111111111111111111111111111111111111100000000000
55555555555555555555555000000000777777770011111111111111111111111111111111111111111111111111111111111111111111111111100000000000
55555555555555555555550000000000777777770011111111111111111111111111111111111111111111111111111111000000000000000000000000000000
55555555555555555555500000000000777733770011111111111111111111111111111111111111111111111111111111000000000000000000000000000000
55555555555555555555000000000000777733770011111111111111111117711111111111111111111111111111111111000000000000000000000000000000
55555555555555555550000000000000737733370011111111111111111117711111111111111111111111111111111111000000000000000000000000000000
555555555555555555000000000000007333bb370011111111111111111111111111111111111111111111111111111111000000000000000000000000000000
555555555555555550000000000000000333bb300011111111111111111111111111111111111111111111111111111111000000000000000000000000000000
55555555555555555000000000060000033333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5555555555555555550000000000000003b33330000000008888888000ee0ee00000000000000000000000000000000000000000000000000000000000000000
5555555555555555555000000000003003333330000000088888888800eeeee00000000000000000000000000000000000000000000000000000000000000000
555555555555555555550000000000b00333b33000000008888ffff8000e8e000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555500000000b30003333000000b00888f1ff1800eeeee00000000000000000000000000000000000000000000000000000000000000000
55555555555555555555550003000b0000044000000b000088fffff000ee3ee00000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555000b0b30000044000030b0030083333000000b0000000000111111111111111111111111111888811111111110000000000000000
555555555555555555555555003033000099990003033030007007000000b0000000000111111111111111111111111118888881111111110000000000000000
55555555555555555555555557777777777777777777777557777777777777750000000111111111111111111111111118788881111111110000000000000005
55555551155555555555555577777777777777777777777777777777777777770000000111111111111111111111111118888881111111110000000000000055
5555550000555555550000557777ccccc777777ccccc77777777cccccccc77770000000111111111111111111111111118888881111111110000000000000555
555550000005555555000055777cccccccc77cccccccc777777cccccccccc7770000000111111111111111111111111118888881111111110000000000005555
55550000000055555500005577cccccccccccccccccccc7777cccccccccccc770000000111111111111111111111111111888811111111110000000000055555
55500000000005555500005577cc77ccccccccccccc7cc7777cc77ccccc7cc770000000111111111111111111111111111161111111111110000000000555555
55000000000000555555555577cc77cccccccccccccccc7777cc77cccccccc770000000111111111111111111111111111161111111111110000000005555555
50000000000000055555555577cccccccccccccccccccc7777cccccccccccc770000000111111111111111111111111111161111111111110000000055555555
00000000000000005555555577cccccccccccccccccccc7777cccccccccccc775000000000000005500000000000000000006000000000050000000055555555
000000000000000005555555777cccccccccccccccccc77777cccccccccccc775500000000000055550000000000000000006000000000550000000050555555
000000000000000000555555777cccccccccccccccccc77777cc7cccc77ccc775550000000000555555000000000000000006000000005550000000055550055
0000000000000000000555557777cccccccccccccccc777777ccccccc77ccc775555000000005555555500000000000000006000000055550600000055550055
0000000000000000000055557777cccccccccccccccc7777777cccccccccc7775555511111155555555555551111111100000000000555550000000055555555
000000000000000000000555777cccccccccccccccccc7777777cccccccc77775555551111555555555555551111111100000000005555550000000055055555
000000000000000000000055777cccccccccccccccccc77777777777777777775555555115555555555555551111111100000000055555550000000055555555
00000000000000006600000577cccccccccccccccccccc7757777777777777755555555555555555555555551111111100000000555555550000000055555555
00000000000000006600000077cccccccccccccccccccccc77777775555555555555555555555555111111111111111100000000555555555000000055555555
000000000000000000000000777ccccccccccccccccccccc77777777155555555555555555555551111111111111111100000000555555555500000055555555
000000000000000000000000777ccccccccccccccccccccccccc7777005555555555555555555511111111111111111111111111555555555551110055555555
0000000000000000007000707777ccccccccccccccccccccccccc777000555555555555555555111111111111111111111111111555555555555110055555555
0000000000000000007000707777cccccccccccccccccccccccccc77000155555555555555551111111111111111111111111111555555555555510055555555
000000000000000006770677777cccccccccccccccccccccccc7cc77000115555555555555511111111111111111111111111111555555555555550055555555
000000000000000056765676777ccccccccccccccccccccccccccc77000111555555555555111111111111111111111111111111555555555555555055555555
00000000000000005666566677cccccccccccccccccccccccccccc77000111155555555551111111111111111111111111111111555555555555555555555555
000000000000000557777777cccccccccccccccccccccccccccccc77000111155555555511111111111111111111111111111115555555555555555555555555
000000000000005577777777ccccccccccccccccccccccccccccc777000000555555555000000000000000001111111111111155555555551555555555555555
00000000000005557777ccccccccccccccccccccccccccccccccc777000005555555550000000000000000001111111111111555555555551155555555555555
0000000000005555777cccccccccccc6cccccccccccccccccccc7777000055555555500000000000000000001111111111115555555555551115555555555555
000000000005555577cccccccccccccccccccccccccccccccccc7777000555555555000000000000000000000000000000055555575555550000555555555555
000000000055555577cc77ccccccccccccccccccccccccccccccc677005555555550000000000000000000000000000000555555555555550000055555555555
000000000555555577cc77ccccccccccccccccccccccccccccccc777055555555500000000000000000000000000000005555555555555550000005555555555
000000005555555577cccccccccccccccccccccccccccccccccccc77555555555000000000000000000000000000000055555555555555550000000555555555

__gff__
0000000000000000020202000008080802020000000000000002000200000000030303030303030302020202020000000303030303030303020202020202020200000303030202020300020202020202000013131302000202020000000000000000030303020000000000000000000000000303030300000002020202020202
0000000000000000030300000000000000000000000000000303030303030300000000000000000003030303030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0002000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
00030000241700e1702d1701617034170201603b160281503f1402f120281101d1101011003110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
011000200177500605017750170523655017750160500605017750060501705076052365500605017750060501775017050177500605236550177501605006050177500605256050160523655256050177523655
002000001d0401d0401d0301d020180401804018030180201b0301b02022040220461f0351f03016040160401d0401d0401d002130611803018030180021f061240502202016040130201d0401b0221804018040
00100000070700706007050110000707007060030510f0700a0700a0600a0500a0000a0700a0600505005040030700306003000030500c0700c0601105016070160600f071050500a07005050030510a0700a060
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
011000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
011000002953429554295741d540225702256018570185701856018500185701856000500165701657216562275142753427554275741f5701f5601f500135201b55135530305602454029570295602257022560
011000200a0700a0500f0710f0500a0600a040110701105007000070001107011050070600704000000000000a0700a0500f0700f0500a0600a0401307113050000000000013070130500f0700f0500000000000
002000002204022030220201b0112404024030270501f0202b0402202027050220202904029030290201601022040220302b0401b030240422403227040180301d0401d0301f0521f0421f0301d0211d0401d030
0108002001770017753f6253b6003c6003b6003f6253160023650236553c600000003f62500000017750170001770017753f6003f6003f625000003f62500000236502365500000000003f625000000000000000
002000200a1400a1300a1201113011120111101b1401b13018152181421813213140131401313013120131100f1400f1300f12011130111201111016142161321315013140131301312013110131101311013100
001000202e750377502e730377302e720377202e71037710227502b750227302b7301d750247501d730247301f750277501f730277301f7202772029750307502973030730297203072029710307102971030710
000600001877035770357703576035750357403573035720357103570000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
001800202945035710294403571029430377102942037710224503571022440274503c710274403c710274202e450357102e440357102e430377102e420377102e410244402b45035710294503c710294403c710
0018002005570055700557005570055700000005570075700a5700a5700a570000000a570000000a5700357005570055700557000000055700557005570000000a570075700c5700c5700f570000000a57007570
010c00103b6352e6003b625000003b61500000000003360033640336303362033610336103f6003f6150000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c002024450307102b4503071024440307002b44037700244203a7102b4203a71024410357102b410357101d45033710244503c7101d4403771024440337001d42035700244202e7101d4102e7102441037700
011800200c5700c5600c550000001157011560115500c5000c5700c5600f5710f56013570135600a5700a5600c5700c5600c550000000f5700f5600f550000000a5700a5600a5500f50011570115600a5700a560
001800200c5700c5600c55000000115701156011550000000c5700c5600f5710f56013570135600f5700f5600c5700c5700c5600c5600c5500c5300c5000c5000c5000a5000a5000a50011500115000a5000a500
000c0020247712477024762247523a0103a010187523a0103501035010187523501018750370003700037000227712277222762227001f7711f7721f762247002277122772227620070027771277722776200700
000c0020247712477024762247523a0103a010187503a01035010350101875035010187501870018700007001f7711f7701f7621f7521870000700187511b7002277122770227622275237012370123701237002
000c0000247712477024772247722476224752247422473224722247120070000700007000070000700007002e0002e0002e0102e010350103501033011330102b0102b0102b0102b00030010300123001230012
000c00200c3320c3320c3220c3220c3120c3120c3120c3020c3320c3320c3220c3220c3120c3120c3120c30207332073320732207322073120731207312073020a3320a3320a3220a3220a3120a3120a3120a302
000c00000c3300c3300c3200c3200c3100c3100c3103a0000c3300c3300c3200c3200c3100c3100c3103f0000a3300a3201333013320073300732007310113000a3300a3200a3103c0000f3300f3200f3103a000
00040000336251a605000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
000c00000c3300c3300c3300c3200c3200c3200c3100c3100c3100c31000000000000000000000000000000000000000000000000000000000000000000000000a3000a3000a3000a3000a3310a3300332103320
001000000c3500c3400c3300c3200f3500f3400f3300f320183501834013350133401835013350163401d36022370223702236022350223402232013300133001830018300133001330016300163001d3001d300
000c0000242752b27530275242652b26530265242552b25530255242452b24530245242352b23530235242252b22530225242152b21530215242052b20530205242052b205302053a2052e205002050020500205
001000102f65501075010753f615010753f6152f65501075010753f615010753f6152f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
0010000016270162701f2711f2701f2701f270182711827013271132701d2711d270162711627016270162701b2711b2701b2701b270000001b200000001b2000000000000000000000000000000000000000000
00080020245753057524545305451b565275651f5752b5751f5452b5451f5352b5351f5252b5251f5152b5151b575275751b545275451b535275351d575295751d545295451d535295351f5752b5751f5452b545
002000200c2650c2650c2550c2550c2450c2450c2350a2310f2650f2650f2550f2550f2450f2450f2351623113265132651325513255132451324513235132351322507240162701326113250132420f2600f250
00100000072750726507255072450f2650f2550c2750c2650c2550c2450c2350c22507275072650725507245072750726507255072450c2650c25511275112651125511245132651325516275162651625516245
000800201f5702b5701f5402b54018550245501b570275701b540275401857024570185402454018530245301b570275701b540275401d530295301d520295201f5702b5701f5402b5401f5302b5301b55027550
00100020112751126511255112451326513255182751826518255182451d2651d2550f2651824513275162550f2750f2650f2550f2451126511255162751626516255162451b2651b255222751f2451826513235
00100010010752f655010753f6152f6553f615010753f615010753f6152f655010752f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
001000100107501075010753f6152f6553f6153f61501075010753f615010753f6152f6553f6152f6553f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
002000002904029040290302b031290242b021290142b01133044300412e0442e03030044300302b0412b0302e0442e0402e030300312e024300212e024300212b0442e0412b0342e0212b0442b0402903129022
000800202451524515245252452524535245352454524545245552455524565245652457500505245750050524565005052456500505245550050524555005052454500505245350050524525005052451500505
000800201f5151f5151f5251f5251f5351f5351f5451f5451f5551f5551f5651f5651f575000051f575000051f565000051f565000051f555000051f555000051f545000051f535000051f525000051f51500005
000500000373005731077410c741137511b7612437030371275702e5712437030371275702e5712436030361275602e5612435030351275502e5512434030341275402e5412433030331275202e5212431030311
002000200c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f2350c2650c2550c2450c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f235112651125511245
002000001327513265132551324513235112651125511245162751626516255162451623513265132551324513275132651325513245132350f2650f2550f2450c25011231162650f24516272162520c2700c255
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00002935500300293453037030360303551330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
001000003c5753c5453c5353c5253c5153c51537555375453a5753a5553a5453a5353a5253a5253a5153a51535575355553554535545355353553535525355253551535515335753355533545335353352533515
00100000355753555535545355353552535525355153551537555375353357533555335453353533525335253a5753a5453a5353a5253a5153a51533575335553354533545335353353533525335253351533515
001000200c0600c0300c0500c0300c0500c0300c0100c0000c0600c0300c0500c0300c0500c0300c0100f0001106011030110501103011010110000a0600a0300a0500a0300a0500a0300a0500a0300a01000000
001000000506005030050500503005010050000706007030070500703007010000000f0600f0300f010000000c0600c0300c0500c0300c0500c0300c0500c0300c0500c0300c010000000c0600c0300c0100c000
0010000003625246150060503615246251b61522625036150060503615116253361522625006051d6250a61537625186152e6251d615006053761537625186152e6251d61511625036150060503615246251d615
00100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00400000302453020530235332252b23530205302253020530205302253020530205302153020530205302152b2452b2052b23527225292352b2052b2252b2052b2052b2252b2052b2052b2152b2052b2052b215
__music__
01 150a5644
00 0a160c44
00 0a160c44
00 0a0b0c44
00 14131244
00 0a160c44
00 0a160c44
02 0a111244
00 41424344
00 41424344
01 18191a44
00 18191a44
00 1c1b1a44
00 1d1b1a44
00 1f211a44
00 1f1a2144
00 1e1a2244
02 201a2444
00 41424344
00 41424344
01 2a272944
00 2a272944
00 2f2b2944
00 2f2b2c44
00 2f2b2944
00 2f2b2c44
00 2e2d3044
00 34312744
02 35322744
00 41424344
01 3d7e4344
00 3d7e4344
00 3d4a4344
02 3d3e4344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 383a3c44
02 393b3c44
