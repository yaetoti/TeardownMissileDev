#version 2

if not Utils then
  Utils = {}

  function Utils.shallowCopy(obj)
    local copy = {}
    for k, v in pairs(obj) do
      copy[k] = v
    end

    return copy
  end

  function Utils.deepCopy(obj)
    if type(obj) ~= "table" then
      return obj
    end

    local copy = {}
    for k, v in pairs(obj) do
      copy[deepCopy(k)] = deepCopy(v)
    end

    return copy
  end
end