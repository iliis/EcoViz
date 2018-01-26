---------------------------------------------------------------------------------------------------

function LOG_OBJ(obj, show_methods, indentation)

	if not indentation then
		indentation = ""
	end

	if type(obj) == "table" then

		--LOG(indentation.."properties of "..tostring(obj))

		local o = obj
		if show_methods then
			LOG(indentation.."\tfunctions():")
			o = getmetatable(obj)
		end
		
		
		for k, v in o do
			if type(v) == "table" then

				if table.getsize(v) == 0 then
					LOG(indentation.."\t"..tostring(k).." = "..tostring(v).." { }")
        elseif k == 'parent' or k == 'gui_parent' then
          LOG(indentation.."\t"..tostring(k).." = "..tostring(v).." { <omitted> }") -- prevent infinite recursion ;)
				else
					LOG(indentation.."\t"..tostring(k).." = "..tostring(v).." {")
					LOG_OBJ(v, show_methods, indentation.."\t")
					LOG(indentation.."\t}")
				end
			else
				LOG(indentation.."\t"..tostring(k).." = "..tostring(v))
			end
		end
	else
		LOG(tostring(obj))
	end
end

---------------------------------------------------------------------------------------------------

function RAISE_EXCEPTION(msg)
  WARN(msg)
  local f = nil
  f.lets_throw_an_error()
end

---------------------------------------------------------------------------------------------------

function ASSERT(cond)
  if not cond then
    RAISE_EXCEPTION("Assertion violated!")
  end
end

---------------------------------------------------------------------------------------------------

function ASSERT_VECT(v)
  if v == nil then
    RAISE_EXCEPTION('vector is nil!')
  else
    ASSERT(v[1] ~= nil and v[2] ~= nil and v[3] ~= nil)
  end
end

---------------------------------------------------------------------------------------------------

function ASSERT_VECT_NONZERO(v)
  ASSERT_VECT(v)
  ASSERT(v[1] ~= 0 and v[2] ~= 0 and v[3] ~= 0)
end

---------------------------------------------------------------------------------------------------

function ASSERT_UNIQUE_SET(t)
  t = table.copy(t)
  --table.sort(t, function(a, b) return t > b:value() end)
  local last_v = nil
  for _, v in t do
    if last_v then
      ASSERT(last_v ~= v)
    end
    last_v = v
  end
end

---------------------------------------------------------------------------------------------------

function vectostr(v)
  return tostring(v[1]) .. ", " .. tostring(v[2]) .. ", " .. tostring(v[3])
end

---------------------------------------------------------------------------------------------------