function parse(tag, timestamp, record)

  local code=0 -- return code for fluent-bit -1=drop record, 0=unmodified, 1=modified

  -- list of parsing states
  local NEW=0
  local LABEL=1
  local LABEL_END=2
  local EQUAL=3
  local VALUE=4
  local ESCAPE=5
  local QUOTED_VALUE=6

  -- parsing current state
  local state=NEW

  -- variable for our new key/value pairs
  local fieldsnew={}

  -- promote metric/value to key/value pair
  if record["metric"] and record["value"] then
    record[record["metric"]]=record["value"]
    code=1 -- tell fluent-bit to keep the modified record
  end

  -- process value of "fields"
  if record["fields"] then 
    -- parse key=value pairs to key/value pairs
    local str = record["fields"]
    local label=""
    local value=""
    for i = 1, #str do
      local c = str:sub(i,i)
      if state==NEW then
        -- looking for a label to start us
        if string.match(c,"[a-zA-Z_]") then
          -- digits and dashes are not allowed at beginning of labels
          label=label..c
          state=LABEL
        end
      elseif state==LABEL then
        -- looking to continue a label
        if string.match(c,"[a-zA-Z0-9_-]") then
          -- digits and dashes can be within a label
          label=label..c
        elseif c=="=" then
          -- LABEL terminated by EQUAL
          state=EQUAL
        elseif c==" " then
          -- LABEL terminaled by SPACE
          state=LABEL_END
        else
          -- unexpected -- ABORT, start anew
          label=""
          state=NEW
        end
      elseif state==LABEL_END then
        if c=="=" then
          state=EQUAL
        elseif c==" " then
          -- ignore SPACEs after LABEL
        else
          -- unexpected -- ABORT
           state=NEW
        end
      elseif state==EQUAL then
        if c==" " then
          -- ignore SPACE(s) after EQUAL
        elseif c=='"' then
          state=QUOTED_VALUE
          -- Quoted values need quotes to terminate
        elseif c=="\\" then
          -- The next charater is escaped
          state=ESCAPE
          value=value..c
        elseif not string.match(c,"[, ]") then
          -- value starts
          state=VALUE
          value=value..c
        else 
          -- unquoted value terminated by space or comma
          -- save the key/value pair, and start scanning anew
          fieldsnew[label]=value
          label=""
          value=""
          state=NEW
        end
      elseif state==QUOTED_VALUE then
        if c=="\\" then
          state=ESCAPE
          value=value..c
        elseif c=='"' then
          -- quoted value ended by quotes, save key/value pair, and start scanning anew
          fieldsnew[label]=value
          label=""
          value=""
          state=NEW
        else
          value=value..c
        end
      elseif state==ESCAPE then
        -- capture escaped char
        state=VALUE
        value=value..c
      elseif state==VALUE then
        -- unquoted values terminated by space or comma, save key/value pair, and start scanning anew
        if string.match(c,"[ ,]") then
          fieldsnew[label]=value
          label=""
          value=""
          state=NEW
        else
          value=value..c
        end
      end
    end
    if fieldsnew then
      -- save all key/value pairs under this key
      record["fieldsnew"]=fieldsnew
      -- tell fluent-bit to keep the modified record
      code=1
    end
  end
  return code, timestamp, record
end
