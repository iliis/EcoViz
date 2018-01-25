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

				if table.getn(v) == 0 then
					LOG(indentation.."\t"..tostring(k).." = { }")
				else
					LOG(indentation.."\t"..tostring(k).." = {")
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
  ASSERT(v ~= nil and v[1] ~= nil and v[2] ~= nil and v[3] ~= nil)
end

---------------------------------------------------------------------------------------------------

function vectostr(v)
  return tostring(v[1]) .. ", " .. tostring(v[2]) .. ", " .. tostring(v[3])
end

---------------------------------------------------------------------------------------------------