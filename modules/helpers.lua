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