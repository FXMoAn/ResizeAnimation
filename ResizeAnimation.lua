local obs = obslua

-- 插件介绍
function script_description()
    return [[
        <center><h1><color=#0000FF>自定义缩放动画效果</color></h1></center>
        <center><h2>作者：墨安</h2></center>
        <center>Inspired by Jojoe's resize animation script</center>
    ]]
end

-- 插件设置
function script_properties()
    local settings = obs.obs_properties_create()

    local source_list = obs.obs_properties_add_list(settings, "source_list", "选择源（窗口）: ", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    make_source_list(source_list)
    local scene_list = obs.obs_properties_add_list(settings, "scene_list", "选择场景: ", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    make_scene_list(scene_list)
    local animation_type_list = obs.obs_properties_add_list(settings, "animation_type_list", "选择动画类型: ", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    make_animation_type_list(animation_type_list)

    return settings
end

-- 获取源列表
function make_source_list(source_list)
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for i, source in ipairs(sources) do
            local name = obs.obs_source_get_name(source)
            obs.obs_property_list_add_string(source_list, name, name)
        end
    end
end

-- 获取场景列表
function make_scene_list(scene_list)
    local scenes = obs.obs_frontend_get_scenes()
    if scenes ~= nil then
        for i, scene in ipairs(scenes) do
            local name = obs.obs_source_get_name(scene)
            obs.obs_property_list_add_string(scene_list, name, name)
        end
    end
end

-- 获取动画类型
function make_animation_type_list(animation_type_list)
    obs.obs_property_list_add_string(animation_type_list, "缓入", "ease_in")
    obs.obs_property_list_add_string(animation_type_list, "缓出", "ease_out")
    obs.obs_property_list_add_string(animation_type_list, "缓入缓出", "ease_in_out")
    obs.obs_property_list_add_string(animation_type_list, "无缓入缓出", "none")
end

-- 拉伸到边界
function ensure_stretch_to_bounds()
    local scene = obs.obs_get_scene_by_name(scene_name)
    local sceneitem = obs.obs_scene_find_source(scene, source_name)
    
    obs.obs_sceneitem_set_bounds_type(sceneitem, 1) -- 拉伸到边界
    obs.obs_sceneitem_set_bounds_alignment(sceneitem, 5) -- 左上对齐
    obs.obs_sceneitem_set_alignment(sceneitem, 5) -- 左上对齐

    obs.obs_scene_release(scene)
end

-- 更新设置
function script_update(settings)
    counter = 0
    bounce_counter = 4
    interval = 10
    local video_info = obs.obs_video_info()
    obs.obs_get_video_info(video_info)    
    canvas_width = video_info.base_width
    canvas_height = video_info.base_height
    bounce_width = canvas_width
    bounce_height = canvas_height
    source_name = obs.obs_data_get_string(settings, "source_list")
    scene_name = obs.obs_data_get_string(settings, "scene_list")

    ensure_stretch_to_bounds()

    local source = obs.obs_get_source_by_name(source_name)
    prev_width, width = obs.obs_source_get_width(source)
    prev_height, height = obs.obs_source_get_height(source)

    obs.timer_remove(update_size)
    obs.timer_add(update_size, 100)
end

-- 获取实例宽高和位置
function get_instance_position()
    local scene = obs.obs_get_scene_by_name(scene_name)
    local sceneitem = obs.obs_scene_find_source(scene, source_name)
    local info = obs.obs_transform_info()
    obs.obs_sceneitem_get_info(sceneitem, info)

    local w = info.bounds.x
    local h = info.bounds.y
    local x = info.pos.x
    local y = info.pos.y
    obs.obs_scene_release(scene)

    return w, h, x, y
end

-- 调整实例宽高和位置
function resize_instance(w,h,x,y)
    local scene = obs.obs_get_scene_by_name(scene_name)
    local sceneitem = obs.obs_scene_find_source(scene, source_name)
    local info = obs.obs_transform_info()
    obs.obs_sceneitem_get_info(sceneitem, info)

    info.bounds.x = w
    info.bounds.y = h
    info.pos.x = x
    info.pos.y = y

    obs.obs_sceneitem_set_info(sceneitem, info)

    obs.obs_scene_release(scene)
end

function update_size(settings)
    local source = obs.obs_get_source_by_name(source_name)
    width = obs.obs_source_get_width(source)
    height = obs.obs_source_get_height(source)

    if width ~= prev_width or height ~= prev_height then
        prev_width = width
        prev_height = height
        print("detected size change: " .. width .. "x" .. height)
        target_width = width
        target_height = height

        if target_width > 0 then
            if target_height >0 then
                counter = 0
                print("resizing to " .. target_width .. "x" .. target_height)
                obs.timer_remove(animate)
                obs.timer_remove(update_size)
                obs.timer_add(animate, interval)
            end
        end
    end
end

function ease_in()
end

function ease_out()
end


function animate()
    w, h, x, y = get_instance_position()
    counter = counter + 1
    print("instance dimensions: " .. w .. "x" .. h .. " at " .. x .. "," .. y)
    print("counter: " .. counter)

    if counter < 10 then
        x_increment = 100 + (counter * 10)  -- was 20 and 5
        if h > 3000 then
            y_increment = 7500
        else
            y_increment = 100 + (counter * 10)  -- was 20 and 5
        end

    else
        x_increment = 500
        y_increment = 500
    end

    print("x increment: " .. x_increment)
    print("y increment: " .. y_increment)
    print("target height: " .. target_height)
    print("target width: " .. target_width)

    if target_height > 3000 then
        y_increment = 7500
    end

    if w < target_width then
        w = w + x_increment
        if w >= target_width then
            w = target_width
        end
    elseif w > target_width then
        w = w - x_increment
        if w <= target_width then
            w = target_width
        end
    end

    if h < target_height then
        h = h + y_increment
        if h >= target_height then
            h = target_height
        end

    elseif h > target_height then
        h = h - y_increment
        if h <= target_height then
            h = target_height
        end
    end

    pos_x = (canvas_width / 2) - (w / 2)
    pos_y = (canvas_height / 2) - (h / 2)

    print("pos x: " .. pos_x)
    print("pos y: " .. pos_y)


    resize_instance(w, h, pos_x, pos_y)

    if w == target_width and h == target_height then
        print("finished resizing")
        obs.timer_remove(animate)
        obs.timer_add(update_size, 100)
        -- if h < 5000 then                        BROKEN idk why 
        --     bounce_counter = 3 
        --     S.timer_add(bounce, 2500)
        -- end
    end
end

function bounce()
    w, h, x, y = get_instance_position()

    bounce_offset = 8

    bounce_width = target_width + (bounce_counter * bounce_offset)
    bounce_height = target_height + (bounce_counter * bounce_offset)
    bounce_increment = 4

    print("bounce_counter: " .. bounce_counter)
    print("bounce_offset: " .. bounce_offset)
    print("bounce_width " .. bounce_width)
    print("bounce_height: " .. bounce_height)
    print("bounce_increment: " .. bounce_increment)

    if target_height > (target_width * 2.5) then  -- thin, bounce width
        print("thin")
        if w < bounce_width then
            w = w + bounce_increment
            if w >= bounce_width then
                w = bounce_width
                bounce_width = target_width - (bounce_counter * bounce_offset)
            end
        elseif w > target_width then
            w = w - bounce_increment
            if w <= bounce_width then
                w = bounce_width
                bounce_width = target_width + (bounce_counter * bounce_offset)
                bounce_counter = bounce_counter - 1
            end
        end
    elseif target_width > (target_height * 2.5) then  -- wide, bounce height
        print("wide")
        if h < bounce_height then
            h = h + bounce_increment
            if h >= bounce_height then
                h = bounce_height
                bounce_height = target_height - (bounce_counter * bounce_offset)
            end
        elseif h > target_height then
            h = h - bounce_increment
            if h <= bounce_height then
                h = bounce_height
                bounce_height = target_height + (bounce_counter * bounce_offset)
                bounce_counter = bounce_counter - 1
            end
        end
    else
        print("none")
        -- no bounce
        bounce_counter = 0
    end
    pos_x = (canvas_width / 2) - (w / 2)
    pos_y = (canvas_height / 2) - (h / 2)

    if bounce_counter == 0 then
        S.timer_remove(bounce)
        pos_x = (canvas_width / 2) - (w / 2)
        pos_y = (canvas_height / 2) - (h / 2)
        w = target_width
        h = target_height

    resize_instance(w, h, pos_x, pos_Y)
    
    end
end