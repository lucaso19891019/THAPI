require_relative 'opencl_model'

class LTTng
  def self.name(*args)
    case args[0]
    when "ctf_string"
      args[1]
    when "ctf_enum"
      args[4]
    else
      args[2]
    end
  end

  def self.array?(*args)
    args[0].match("array") || args[0].match("sequence")
  end

  def self.string?(*args)
    args[0].match("string")
  end

  def self.expression(*args)
    case args[0]
    when "ctf_string"
      args[2]
    when "ctf_enum"
      args[5]
    else
      args[3]
    end
  end

end

en = YAML::load_file("supported_enums.yaml")
en.push( { "name" => "cl_bool"} )
en.push( { "name" => "command execution status", "trace_name" => "command_exec_callback_type", "type_name" => "cl_command_execution_status" } )

bitfields = {}
enums = {}
objects = CL_OBJECTS + CL_EXT_OBJECTS
int_scalars = CL_INT_SCALARS
float_scalars = CL_FLOAT_SCALARS
events = {}

res = {
  "enums" => enums,
  "bitfields" => bitfields,
  "objects" => objects,
  "int_scalars" => int_scalars,
  "float_scalars" => float_scalars,
  "events" => events
}

en.each { |e|
  bitfield = false
  vals = $requires.select { |r|
    r.comment && r.comment.match(/#{e["name"]}(\z| )/)
  }.each { |r|
    bitfield = true if r.comment.match(/ - bitfield/)
  }.collect { |r|
    r.enums
  }.reduce(:+).collect { |v|
    [v, $constants[v]]
  }.to_h
  r = { "values" => vals}
  r["trace_name"] = e["trace_name"] if e["trace_name"]
  r["type_name"] = e["type_name"] if e["type_name"]

  if bitfield
    bitfields[e["name"]] = r
  else
    enums[e["name"]] = r
  end
}

event_lambda = lambda { |c, dir|
  name = "lttng_ust_opencl:#{c.prototype.name}_#{dir}"
  fields = {}
  params = {}
  c.parameters.each { |p|
    param = {}
    params[p.name] = param
    param["type"] = (p.type == '' ? "void" : p.type)
    param["pointer"] = p.pointer?
  }
  meta_structs = []
  if $meta_parameters["meta_structs"][c.prototype.name]
    meta_structs = $meta_parameters["meta_structs"][c.prototype.name]
  end
  meta_structs = meta_structs.to_h
  meta_structs = meta_structs.collect { |pname, type|
    [pname, CL_STRUCT_MAP[type].collect { |m|
      Member::new(c, m, pname)
    }.collect { |m|
      [m.name, m]
    }.to_h]
  }.to_h
  if dir == :start
    c.parameters.select { |p| p.lttng_in_type }.each { |p|
      field = {}
      lttng = p.lttng_in_type
      fname = LTTng.name(*lttng)
      field.merge!(params[fname])
      field["lttng"] = lttng[0]
      fields[fname] = field
    }
    c.meta_parameters.select { |p| p.lttng_in_type }.each { |p|
      meta_field = {}
      lttng = p.lttng_in_type
      fname = LTTng.name(*lttng)
      if fname == "errcode_ret_val"
        meta_field["type"] = "cl_int"
      elsif fname.match(/_val\z/)
        pname = fname.gsub(/_val\z/, "")
        meta_field["type"] = params[pname]["type"]
      else
        begin
          meta_field["type"] = params[LTTng.expression(*lttng)]["type"]
        rescue #must be a struct member
          pname = LTTng.expression(*lttng).match(/(\w+) != NULL/)[1]
          m = meta_structs[pname][fname.gsub(/\A#{pname}_/,"")]
          meta_field["name"] = m.name
          meta_field["type"] = m.type
          meta_field["pointer"] = m.pointer? if m.pointer?
          meta_field["struct"] = pname
        end
      end
      meta_field["lttng"] = lttng[0]
      fields[fname] = meta_field
    }
  else
    field = {}
    if c.prototype.lttng_return_type
      field["type"] = c.prototype.return_type
      lttng = c.prototype.lttng_return_type
      field["lttng"] = lttng[0]
      fname = LTTng.name(*lttng)
      fields[fname] = field
    end
    c.meta_parameters.select { |p| p.lttng_out_type }.each { |p|
      meta_field = {}
      lttng = p.lttng_out_type
      fname = LTTng.name(*lttng)
      if fname == "errcode_ret_val"
        meta_field["type"] = "cl_int"
      elsif fname.match(/_val\z/)
        pname = fname.gsub(/_val\z/, "")
        meta_field["type"] = params[pname]["type"]
      else
        begin
          meta_field["type"] = params[LTTng.expression(*lttng)]["type"]
        rescue
          $stderr.puts name, lttng.inspect
        end
      end
      meta_field["lttng"] = lttng[0]
      fields[fname] = meta_field
    }
  end
  [name, fields]
}

($opencl_commands+$opencl_extension_commands).each { |c|
  [:start, :stop].each { |dir|
    name, val = event_lambda.call(c, dir)
    events[name] = val
  }
}

puts YAML::dump(res)