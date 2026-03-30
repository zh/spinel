# Spinel v2 Codegen - Ruby subset AOT compiler backend
#
# Reads text AST from spinel_parse.rb, generates standalone C code.
# Written in Spinel-compilable Ruby subset.
#
# Usage: ruby spinel_codegen.rb ast.txt output.c
#
# All data structures use parallel arrays (no arrays of objects).
# Node fields stored as parallel arrays indexed by integer node ID.

class Compiler
  attr_accessor :out

  def initialize
    @out = ""
    @indent = 0
    @temp_counter = 0
    @label_counter = 0

    # ---- AST node storage (parallel arrays by node ID) ----
    # Use "".split(",") for StrArray init (v1 infers StrArray from split)
    @nd_type = "".split(",")
    @nd_name = "".split(",")
    @nd_value = []
    @nd_content = "".split(",")
    @nd_flags = []
    @nd_operator = "".split(",")
    @nd_binop = "".split(",")
    @nd_callop = "".split(",")
    @nd_unescaped = "".split(",")

    # Node references (integer node IDs, -1 = nil)
    @nd_receiver = []
    @nd_arguments = []
    @nd_body = []
    @nd_block = []
    @nd_parameters = []
    @nd_predicate = []
    @nd_subsequent = []
    @nd_else_clause = []
    @nd_left = []
    @nd_right = []
    @nd_constant_path = []
    @nd_superclass = []
    @nd_rest = []
    @nd_rescue_clause = []
    @nd_ensure_clause = []
    @nd_expression = []
    @nd_target = []
    @nd_pattern = []
    @nd_key = []
    @nd_reference = []
    @nd_collection = []

    # Node array fields: stored as comma-separated ID strings
    @nd_stmts = "".split(",")
    @nd_args = "".split(",")
    @nd_requireds = "".split(",")
    @nd_optionals = "".split(",")
    @nd_keywords = "".split(",")
    @nd_elements = "".split(",")
    @nd_parts = "".split(",")
    @nd_conditions = "".split(",")
    @nd_exceptions = "".split(",")
    @nd_targets = "".split(",")

    @nd_count = 0
    @root_id = 0

    # ---- Top-level methods (parallel arrays) ----
    @meth_names = "".split(",")
    @meth_param_names = "".split(",")
    @meth_param_types = "".split(",")
    @meth_return_types = "".split(",")
    @meth_body_ids = []
    @meth_has_defaults = "".split(",")

    # ---- Classes (parallel arrays) ----
    @cls_names = "".split(",")
    @cls_parents = "".split(",")
    @cls_ivar_names = "".split(",")
    @cls_ivar_types = "".split(",")
    @cls_meth_names = "".split(",")
    @cls_meth_params = "".split(",")
    @cls_meth_ptypes = "".split(",")
    @cls_meth_returns = "".split(",")
    @cls_meth_bodies = "".split(",")
    @cls_meth_defaults = "".split(",")
    @cls_attr_readers = "".split(",")
    @cls_attr_writers = "".split(",")
    @cls_cmeth_names = "".split(",")
    @cls_cmeth_params = "".split(",")
    @cls_cmeth_ptypes = "".split(",")
    @cls_cmeth_returns = "".split(",")
    @cls_cmeth_bodies = "".split(",")

    # ---- Constants (parallel arrays) ----
    @const_names = "".split(",")
    @const_types = "".split(",")
    @const_expr_ids = []

    # ---- Scope stack for local variables ----
    @scope_names = "".split(",")
    @scope_types = "".split(",")

    @current_class_idx = -1
    @current_method_name = ""
    @current_method_return = ""
    @in_main = 0
    @in_loop = 0
    @in_yield_method = 0

    # Yield/block tracking (parallel with meth_names / cls_meth_names)
    @meth_has_yield = []
    @cls_meth_has_yield = "".split(",")

    # Block function accumulator (emitted before forward decls)
    @block_funcs = ""
    @block_counter = 0

    # Feature flags
    @needs_gc = 0
    @needs_int_array = 0
    @needs_str_array = 0
    @needs_str_int_hash = 0
    @needs_str_str_hash = 0
    @needs_string_helpers = 0
    @needs_setjmp = 0
    @needs_file_io = 0
    @needs_mutable_str = 0
    @needs_rb_value = 0

    # Poly tracking: functions with params called with different types
    @poly_funcs = "".split(",")
    @poly_param_types = "".split(",")
  end

  def join_sep(arr, sep)
    result = ""
    i = 0
    while i < arr.length
      if i > 0
        result = result + sep
      end
      result = result + arr[i]
      i = i + 1
    end
    result
  end

  # Parse comma-sep node IDs into IntArray
  def parse_id_list(s)
    if s == ""
      return []
    end
    parts = s.split(",")
    result = []
    i = 0
    while i < parts.length
      result.push(parts[i].to_i)
      i = i + 1
    end
    result
  end

  def new_temp
    @temp_counter = @temp_counter + 1
    "_t" + @temp_counter.to_s
  end

  def new_label
    @label_counter = @label_counter + 1
    "_L" + @label_counter.to_s
  end

  # ---- AST reader ----
  def alloc_node
    nid = @nd_count
    @nd_type.push("")
    @nd_name.push("")
    @nd_value.push(0)
    @nd_content.push("")
    @nd_flags.push(0)
    @nd_operator.push("")
    @nd_binop.push("")
    @nd_callop.push("")
    @nd_unescaped.push("")
    @nd_receiver.push(-1)
    @nd_arguments.push(-1)
    @nd_body.push(-1)
    @nd_block.push(-1)
    @nd_parameters.push(-1)
    @nd_predicate.push(-1)
    @nd_subsequent.push(-1)
    @nd_else_clause.push(-1)
    @nd_left.push(-1)
    @nd_right.push(-1)
    @nd_constant_path.push(-1)
    @nd_superclass.push(-1)
    @nd_rest.push(-1)
    @nd_rescue_clause.push(-1)
    @nd_ensure_clause.push(-1)
    @nd_expression.push(-1)
    @nd_target.push(-1)
    @nd_pattern.push(-1)
    @nd_key.push(-1)
    @nd_reference.push(-1)
    @nd_collection.push(-1)
    @nd_stmts.push("")
    @nd_args.push("")
    @nd_requireds.push("")
    @nd_optionals.push("")
    @nd_keywords.push("")
    @nd_elements.push("")
    @nd_parts.push("")
    @nd_conditions.push("")
    @nd_exceptions.push("")
    @nd_targets.push("")
    @nd_count = @nd_count + 1
    nid
  end

  def read_text_ast(data)
    lines = data.split("\n")
    # First pass: find max node ID
    max_id = 0
    i = 0
    while i < lines.length
      line = lines[i]
      if line.length > 0
        parts = line.split(" ")
        if parts.length >= 2
          if parts[0] == "ROOT"
            @root_id = parts[1].to_i
          end
          if parts[0] == "N"
            nid = parts[1].to_i
            if nid > max_id
              max_id = nid
            end
          end
        end
      end
      i = i + 1
    end

    # Allocate all nodes
    j = 0
    while j <= max_id
      alloc_node
      j = j + 1
    end

    # Second pass: populate fields
    i = 0
    while i < lines.length
      line = lines[i]
      if line.length > 0
        parts = line.split(" ")
        if parts.length >= 3
          tag = parts[0]
          nid = parts[1].to_i
          if tag == "N"
            @nd_type[nid] = parts[2]
          end
          if tag == "S"
            field = parts[2]
            val = ""
            if parts.length >= 4
              val = unescape_str(parts[3])
            end
            set_string_field(nid, field, val)
          end
          if tag == "I"
            field = parts[2]
            val = 0
            if parts.length >= 4
              val = parts[3].to_i
            end
            set_int_field(nid, field, val)
          end
          if tag == "F"
            field = parts[2]
            if parts.length >= 4
              @nd_content[nid] = parts[3]
            end
          end
          if tag == "R"
            field = parts[2]
            ref_id = -1
            if parts.length >= 4
              ref_id = parts[3].to_i
            end
            set_ref_field(nid, field, ref_id)
          end
          if tag == "A"
            field = parts[2]
            ids_str = ""
            if parts.length >= 4
              ids_str = parts[3]
            end
            set_array_field(nid, field, ids_str)
          end
        end
      end
      i = i + 1
    end
  end

  def unescape_str(s)
    result = ""
    i = 0
    while i < s.length
      ch = s[i]
      if ch == "%"
        if i + 2 < s.length
          hex = s[i + 1] + s[i + 2]
          if hex == "0A"
            result = result + "\n"
            i = i + 3
          else
            if hex == "0D"
              result = result + "\r"
              i = i + 3
            else
              if hex == "09"
                result = result + "\t"
                i = i + 3
              else
                if hex == "20"
                  result = result + " "
                  i = i + 3
                else
                  if hex == "25"
                    result = result + "%"
                    i = i + 3
                  else
                    result = result + "%" + hex
                    i = i + 3
                  end
                end
              end
            end
          end
        else
          result = result + ch
          i = i + 1
        end
      else
        result = result + ch
        i = i + 1
      end
    end
    result
  end

  def set_string_field(nid, field, val)
    if field == "name"
      @nd_name[nid] = val
    end
    if field == "content"
      @nd_content[nid] = val
    end
    if field == "value"
      @nd_content[nid] = val
    end
    if field == "operator"
      @nd_operator[nid] = val
    end
    if field == "binary_operator"
      @nd_binop[nid] = val
    end
    if field == "call_operator"
      @nd_callop[nid] = val
    end
    if field == "unescaped"
      @nd_unescaped[nid] = val
    end
  end

  def set_int_field(nid, field, val)
    if field == "value"
      @nd_value[nid] = val
    end
    if field == "flags"
      @nd_flags[nid] = val
    end
    if field == "number"
      @nd_value[nid] = val
    end
    if field == "maximum"
      @nd_value[nid] = val
    end
    if field == "start_line"
      @nd_value[nid] = val
    end
  end

  def set_ref_field(nid, field, ref_id)
    if field == "receiver"
      @nd_receiver[nid] = ref_id
    end
    if field == "arguments"
      @nd_arguments[nid] = ref_id
    end
    if field == "body"
      @nd_body[nid] = ref_id
    end
    if field == "block"
      @nd_block[nid] = ref_id
    end
    if field == "parameters"
      @nd_parameters[nid] = ref_id
    end
    if field == "predicate"
      @nd_predicate[nid] = ref_id
    end
    if field == "subsequent"
      @nd_subsequent[nid] = ref_id
    end
    if field == "else_clause"
      @nd_else_clause[nid] = ref_id
    end
    if field == "left"
      @nd_left[nid] = ref_id
    end
    if field == "right"
      @nd_right[nid] = ref_id
    end
    if field == "constant_path"
      @nd_constant_path[nid] = ref_id
    end
    if field == "superclass"
      @nd_superclass[nid] = ref_id
    end
    if field == "rest"
      @nd_rest[nid] = ref_id
    end
    if field == "rescue_clause"
      @nd_rescue_clause[nid] = ref_id
    end
    if field == "ensure_clause"
      @nd_ensure_clause[nid] = ref_id
    end
    if field == "expression"
      @nd_expression[nid] = ref_id
    end
    if field == "target"
      @nd_target[nid] = ref_id
    end
    if field == "pattern"
      @nd_pattern[nid] = ref_id
    end
    if field == "key"
      @nd_key[nid] = ref_id
    end
    if field == "reference"
      @nd_reference[nid] = ref_id
    end
    if field == "collection"
      @nd_collection[nid] = ref_id
    end
    if field == "statements"
      @nd_body[nid] = ref_id
    end
    if field == "value"
      @nd_expression[nid] = ref_id
    end
    if field == "index"
      @nd_target[nid] = ref_id
    end
    if field == "parent"
      @nd_receiver[nid] = ref_id
    end
    if field == "rescue_expression"
      @nd_else_clause[nid] = ref_id
    end
    if field == "call"
      @nd_receiver[nid] = ref_id
    end
  end

  def set_array_field(nid, field, ids_str)
    if field == "body"
      @nd_stmts[nid] = ids_str
    end
    if field == "arguments"
      @nd_args[nid] = ids_str
    end
    if field == "requireds"
      @nd_requireds[nid] = ids_str
    end
    if field == "optionals"
      @nd_optionals[nid] = ids_str
    end
    if field == "keywords"
      @nd_keywords[nid] = ids_str
    end
    if field == "elements"
      @nd_elements[nid] = ids_str
    end
    if field == "parts"
      @nd_parts[nid] = ids_str
    end
    if field == "conditions"
      @nd_conditions[nid] = ids_str
    end
    if field == "exceptions"
      @nd_exceptions[nid] = ids_str
    end
    if field == "lefts"
      @nd_targets[nid] = ids_str
    end
    if field == "targets"
      @nd_targets[nid] = ids_str
    end
  end

  # ---- Convenience: get stmts of a body node ----
  def get_stmts(nid)
    if nid < 0
      return []
    end
    # If it's a StatementsNode, return its stmts
    if @nd_type[nid] == "StatementsNode"
      return parse_id_list(@nd_stmts[nid])
    end
    # Otherwise return single-element array
    result = []
    result.push(nid)
    result
  end

  def get_body_stmts(nid)
    body = @nd_body[nid]
    if body < 0
      return []
    end
    get_stmts(body)
  end

  def get_args(nid)
    # nid is an ArgumentsNode
    if nid < 0
      return []
    end
    if @nd_type[nid] == "ArgumentsNode"
      return parse_id_list(@nd_args[nid])
    end
    result = []
    result.push(nid)
    result
  end

  # ---- Scope management ----
  def push_scope
    @scope_names.push("---")
    @scope_types.push("---")
  end

  def pop_scope
    while @scope_names.length > 0
      top_name = @scope_names[@scope_names.length - 1]
      if top_name == "---"
        @scope_names.pop
        @scope_types.pop
        return
      end
      @scope_names.pop
      @scope_types.pop
    end
  end

  def declare_var(name, vtype)
    @scope_names.push(name)
    @scope_types.push(vtype)
  end

  def find_var_type(name)
    i = @scope_names.length - 1
    while i >= 0
      if @scope_names[i] == name
        return @scope_types[i]
      end
      i = i - 1
    end
    ""
  end

  def set_var_type(name, vtype)
    i = @scope_names.length - 1
    while i >= 0
      if @scope_names[i] == name
        @scope_types[i] = vtype
        return
      end
      i = i - 1
    end
  end

  # ---- Class/Method lookup (all parallel arrays) ----
  def find_class_idx(name)
    i = 0
    while i < @cls_names.length
      if @cls_names[i] == name
        return i
      end
      i = i + 1
    end
    -1
  end

  def find_method_idx(name)
    i = 0
    while i < @meth_names.length
      if @meth_names[i] == name
        return i
      end
      i = i + 1
    end
    -1
  end

  def find_const_idx(name)
    i = 0
    while i < @const_names.length
      if @const_names[i] == name
        return i
      end
      i = i + 1
    end
    -1
  end

  # Find method in class (search parent chain)
  def cls_find_method(ci, mname)
    names = @cls_meth_names[ci].split(";")
    j = 0
    while j < names.length
      if names[j] == mname
        return j
      end
      j = j + 1
    end
    # Check parent
    if @cls_parents[ci] != ""
      pi = find_class_idx(@cls_parents[ci])
      if pi >= 0
        return cls_find_method(pi, mname)
      end
    end
    -1
  end

  # Get method return type from class
  def cls_method_return(ci, mname)
    names = @cls_meth_names[ci].split(";")
    returns = @cls_meth_returns[ci].split(";")
    j = 0
    while j < names.length
      if names[j] == mname
        if j < returns.length
          return returns[j]
        end
        return "int"
      end
      j = j + 1
    end
    if @cls_parents[ci] != ""
      pi = find_class_idx(@cls_parents[ci])
      if pi >= 0
        return cls_method_return(pi, mname)
      end
    end
    "int"
  end

  # Get ivar type from class
  def cls_ivar_type(ci, iname)
    names = @cls_ivar_names[ci].split(";")
    types = @cls_ivar_types[ci].split(";")
    j = 0
    while j < names.length
      if names[j] == iname
        if j < types.length
          return types[j]
        end
        return "int"
      end
      j = j + 1
    end
    if @cls_parents[ci] != ""
      pi = find_class_idx(@cls_parents[ci])
      if pi >= 0
        return cls_ivar_type(pi, iname)
      end
    end
    "int"
  end

  # ---- Emit helpers ----
  def emit(s)
    ind = ""
    j = 0
    while j < @indent
      ind = ind + "  "
      j = j + 1
    end
    @out = @out + ind + s + "\n"
  end

  def emit_raw(s)
    @out = @out + s + "\n"
  end

  # ---- Type inference ----
  def infer_type(nid)
    if nid < 0
      return "void"
    end
    t = @nd_type[nid]
    if t == "IntegerNode"
      return "int"
    end
    if t == "FloatNode"
      return "float"
    end
    if t == "StringNode"
      return "string"
    end
    if t == "SymbolNode"
      return "string"
    end
    if t == "InterpolatedStringNode"
      return "string"
    end
    if t == "TrueNode"
      return "bool"
    end
    if t == "FalseNode"
      return "bool"
    end
    if t == "NilNode"
      return "nil"
    end
    if t == "XStringNode"
      return "string"
    end
    if t == "InterpolatedXStringNode"
      return "string"
    end
    if t == "ArrayNode"
      return infer_array_elem_type(nid)
    end
    if t == "HashNode"
      return infer_hash_val_type(nid)
    end
    if t == "RangeNode"
      return "range"
    end
    if t == "LocalVariableReadNode"
      vt = find_var_type(@nd_name[nid])
      if vt != ""
        return vt
      end
      return "int"
    end
    if t == "InstanceVariableReadNode"
      if @current_class_idx >= 0
        return cls_ivar_type(@current_class_idx, @nd_name[nid])
      end
      return "int"
    end
    if t == "ConstantReadNode"
      if @nd_name[nid] == "ARGV"
        return "argv"
      end
      ci = find_const_idx(@nd_name[nid])
      if ci >= 0
        return @const_types[ci]
      end
      cx = find_class_idx(@nd_name[nid])
      if cx >= 0
        return "class_" + @nd_name[nid]
      end
      return "int"
    end
    if t == "ConstantPathNode"
      if @nd_receiver[nid] >= 0
        rname = @nd_name[@nd_receiver[nid]]
        nname = @nd_name[nid]
        cpname = rname + "_" + nname
        ci = find_const_idx(cpname)
        if ci >= 0
          return @const_types[ci]
        end
        if rname == "Float"
          return "float"
        end
      end
      return "int"
    end
    if t == "CallNode"
      return infer_call_type(nid)
    end
    if t == "IfNode"
      body = @nd_body[nid]
      if body >= 0
        stmts = get_stmts(body)
        if stmts.length > 0
          return infer_type(stmts[stmts.length - 1])
        end
      end
      return "void"
    end
    if t == "CaseMatchNode"
      # Infer from first in branch
      conds = parse_id_list(@nd_conditions[nid])
      if conds.length > 0
        inid = conds[0]
        if @nd_type[inid] == "InNode"
          ibody = @nd_body[inid]
          if ibody >= 0
            is = get_stmts(ibody)
            if is.length > 0
              return infer_type(is[is.length - 1])
            end
          end
        end
      end
      return "int"
    end
    if t == "CaseNode"
      # Infer from first when branch
      conds = parse_id_list(@nd_conditions[nid])
      if conds.length > 0
        wid = conds[0]
        if @nd_type[wid] == "WhenNode"
          wbody = @nd_body[wid]
          if wbody >= 0
            ws = get_stmts(wbody)
            if ws.length > 0
              return infer_type(ws[ws.length - 1])
            end
          end
        end
      end
      return "int"
    end
    if t == "AndNode"
      return "bool"
    end
    if t == "OrNode"
      return infer_type(@nd_left[nid])
    end
    if t == "ParenthesesNode"
      body = @nd_body[nid]
      if body >= 0
        stmts = get_stmts(body)
        if stmts.length > 0
          return infer_type(stmts[stmts.length - 1])
        end
      end
      return "void"
    end
    if t == "SelfNode"
      if @current_class_idx >= 0
        return "obj_" + @cls_names[@current_class_idx]
      end
      return "int"
    end
    "int"
  end

  def infer_array_elem_type(nid)
    elems = parse_id_list(@nd_elements[nid])
    if elems.length > 0
      et = infer_type(elems[0])
      if et == "string"
        return "str_array"
      end
    end
    "int_array"
  end

  def infer_hash_val_type(nid)
    elems = parse_id_list(@nd_elements[nid])
    if elems.length > 0
      eid = elems[0]
      if @nd_type[eid] == "AssocNode"
        vt = infer_type(@nd_expression[eid])
        if vt == "string"
          return "str_str_hash"
        end
      end
    end
    "str_int_hash"
  end

  def infer_call_type(nid)
    mname = @nd_name[nid]
    recv = @nd_receiver[nid]

    if mname == "+"
      if recv >= 0
        lt = infer_type(recv)
        if lt == "string"
          return "string"
        end
        if lt == "poly"
          return "poly"
        end
        if lt == "float"
          return "float"
        end
      end
      return "int"
    end
    if mname == "-"
      if recv >= 0
        lt = infer_type(recv)
        if lt == "float"
          return "float"
        end
      end
      return "int"
    end
    if mname == "*"
      if recv >= 0
        lt = infer_type(recv)
        if lt == "float"
          return "float"
        end
        if lt == "string"
          return "string"
        end
        if lt == "poly"
          return "poly"
        end
      end
      return "int"
    end
    if mname == "/"
      if recv >= 0
        lt = infer_type(recv)
        if lt == "float"
          return "float"
        end
      end
      return "int"
    end
    if mname == "%"
      return "int"
    end
    if mname == "<"
      return "bool"
    end
    if mname == ">"
      return "bool"
    end
    if mname == "<="
      return "bool"
    end
    if mname == ">="
      return "bool"
    end
    if mname == "=="
      return "bool"
    end
    if mname == "!="
      return "bool"
    end
    if mname == "!"
      return "bool"
    end
    if mname == "length"
      return "int"
    end
    if mname == "to_s"
      return "string"
    end
    if mname == "to_i"
      return "int"
    end
    if mname == "to_f"
      return "float"
    end
    if mname == "ceil"
      return "int"
    end
    if mname == "floor"
      return "int"
    end
    if mname == "round"
      return "int"
    end
    if mname == "upcase"
      return "string"
    end
    if mname == "downcase"
      return "string"
    end
    if mname == "strip"
      return "string"
    end
    if mname == "chomp"
      return "string"
    end
    if mname == "include?"
      return "bool"
    end
    if mname == "start_with?"
      return "bool"
    end
    if mname == "end_with?"
      return "bool"
    end
    if mname == "even?"
      return "bool"
    end
    if mname == "odd?"
      return "bool"
    end
    if mname == "zero?"
      return "bool"
    end
    if mname == "frozen?"
      return "bool"
    end
    if mname == "is_a?"
      return "bool"
    end
    if mname == "respond_to?"
      return "bool"
    end
    if mname == "chr"
      return "string"
    end
    if mname == "gcd"
      return "int"
    end
    if mname == "clamp"
      return "int"
    end
    if mname == "__method__"
      return "string"
    end
    if mname == "join"
      return "string"
    end
    if mname == "uniq"
      if recv >= 0
        return infer_type(recv)
      end
      return "int_array"
    end
    if mname == "to_sym"
      return "string"
    end
    if mname == "lstrip"
      return "string"
    end
    if mname == "rstrip"
      return "string"
    end
    if mname == "dup"
      if recv >= 0
        return infer_type(recv)
      end
      return "string"
    end
    if mname == "ord"
      return "int"
    end
    if mname == "format"
      return "string"
    end
    if mname == "sprintf"
      return "string"
    end
    if mname == "positive?"
      return "bool"
    end
    if mname == "negative?"
      return "bool"
    end
    if mname == "empty?"
      return "bool"
    end
    if mname == "nil?"
      return "bool"
    end
    if mname == "abs"
      if recv >= 0
        lt = infer_type(recv)
        if lt == "float"
          return "float"
        end
      end
      return "int"
    end
    if mname == "**"
      if recv >= 0
        lt = infer_type(recv)
        if lt == "float"
          return "float"
        end
      end
      return "int"
    end
    if mname == "has_key?"
      return "bool"
    end
    if mname == "split"
      return "str_array"
    end
    if mname == "gsub"
      return "string"
    end
    if mname == "sub"
      return "string"
    end
    if mname == "capitalize"
      return "string"
    end
    if mname == "tr"
      return "string"
    end
    if mname == "delete"
      if recv >= 0
        rt = infer_type(recv)
        if rt == "string"
          return "string"
        end
      end
    end
    if mname == "squeeze"
      return "string"
    end
    if mname == "slice"
      return "string"
    end
    if mname == "ljust"
      return "string"
    end
    if mname == "rjust"
      return "string"
    end
    if mname == "center"
      return "string"
    end
    if mname == "chars"
      return "str_array"
    end
    if mname == "bytes"
      return "int_array"
    end
    if mname == "hex"
      return "int"
    end
    if mname == "oct"
      return "int"
    end
    if mname == "count"
      return "int"
    end
    if mname == "size"
      return "int"
    end
    if mname == "index"
      return "int"
    end
    if mname == "keys"
      return "str_array"
    end
    if mname == "push"
      if recv >= 0
        return infer_type(recv)
      end
      return "int_array"
    end
    if mname == "pop"
      if recv >= 0
        rt = infer_type(recv)
        if rt == "str_array"
          return "string"
        end
      end
      return "int"
    end
    if mname == "sort"
      if recv >= 0
        return infer_type(recv)
      end
      return "int_array"
    end
    if mname == "first"
      if recv >= 0
        rt = infer_type(recv)
        if rt == "str_array"
          return "string"
        end
      end
      return "int"
    end
    if mname == "last"
      if recv >= 0
        rt = infer_type(recv)
        if rt == "str_array"
          return "string"
        end
      end
      return "int"
    end
    if mname == "min"
      return "int"
    end
    if mname == "max"
      return "int"
    end
    if mname == "sum"
      return "int"
    end
    if mname == "reverse"
      if recv >= 0
        return infer_type(recv)
      end
      return "int_array"
    end
    if mname == "reject"
      if recv >= 0
        return infer_type(recv)
      end
      return "int_array"
    end
    if mname == "map"
      if recv >= 0
        return infer_type(recv)
      end
      return "int_array"
    end
    if mname == "select"
      if recv >= 0
        return infer_type(recv)
      end
      return "int_array"
    end
    if mname == "[]"
      if recv >= 0
        rt = infer_type(recv)
        if rt == "string"
          return "string"
        end
        if rt == "int_array"
          return "int"
        end
        if rt == "str_array"
          return "string"
        end
        if rt == "str_int_hash"
          return "int"
        end
        if rt == "str_str_hash"
          return "string"
        end
      end
      return "int"
    end
    if mname == "puts"
      return "void"
    end
    if mname == "print"
      return "void"
    end
    if mname == "new"
      if recv >= 0
        if @nd_type[recv] == "ConstantReadNode"
          rn = @nd_name[recv]
          if rn == "Array"
            return "int_array"
          end
          if rn == "Hash"
            return "str_int_hash"
          end
          return "obj_" + rn
        end
      end
    end
    # File operations
    if recv >= 0
      if @nd_type[recv] == "ConstantReadNode"
        rcname = @nd_name[recv]
        if rcname == "File"
          if mname == "read"
            return "string"
          end
          if mname == "exist?"
            return "bool"
          end
          if mname == "join"
            return "string"
          end
          if mname == "basename"
            return "string"
          end
        end
        if rcname == "ENV"
          if mname == "[]"
            return "string"
          end
        end
        if rcname == "Dir"
          if mname == "home"
            return "string"
          end
        end
      end
    end
    # backtick
    if mname == "`"
      return "string"
    end
    if mname == "sqrt"
      return "float"
    end
    if mname == "freeze"
      if recv >= 0
        return infer_type(recv)
      end
      return "string"
    end
    if mname == "to_a"
      if recv >= 0
        rt = infer_type(recv)
        if rt == "range"
          return "int_array"
        end
        if rt == "int_array"
          return "int_array"
        end
      end
      return "int_array"
    end

    # Method call on poly
    if recv >= 0
      rt = infer_type(recv)
      if rt == "poly"
        if mname == "nil?"
          return "bool"
        end
        # Check all classes for this method and return the first matching return type
        ci = 0
        while ci < @cls_names.length
          midx = cls_find_method_direct(ci, mname)
          if midx >= 0
            return cls_method_return(ci, mname)
          end
          ci = ci + 1
        end
        return "int"
      end
      if is_obj_type(rt) == 1
        cname = rt[4, rt.length - 4]
        ci = find_class_idx(cname)
        if ci >= 0
          # Check attr_reader
          readers = @cls_attr_readers[ci].split(";")
          j = 0
          while j < readers.length
            if readers[j] == mname
              return cls_ivar_type(ci, "@" + mname)
            end
            j = j + 1
          end
          # Check method
          mr = cls_method_return(ci, mname)
          if mr != "int"
            return mr
          end
          # If method exists, return its return type
          mi = cls_find_method(ci, mname)
          if mi >= 0
            return cls_method_return(ci, mname)
          end
        end
      end
    end

    # Top-level method
    mi = find_method_idx(mname)
    if mi >= 0
      return @meth_return_types[mi]
    end

    # Bare method call in class context
    if @current_class_idx >= 0
      mr = cls_method_return(@current_class_idx, mname)
      return mr
    end

    "int"
  end

  def is_class_or_ancestor(cname, target)
    if cname == target
      return 1
    end
    ci = find_class_idx(cname)
    if ci >= 0
      if @cls_parents[ci] != ""
        return is_class_or_ancestor(@cls_parents[ci], target)
      end
    end
    0
  end

  def is_operator_name(name)
    if name == "+"
      return 1
    end
    if name == "-"
      return 1
    end
    if name == "*"
      return 1
    end
    if name == "/"
      return 1
    end
    if name == "%"
      return 1
    end
    if name == "<"
      return 1
    end
    if name == ">"
      return 1
    end
    if name == "<="
      return 1
    end
    if name == ">="
      return 1
    end
    if name == "=="
      return 1
    end
    if name == "!="
      return 1
    end
    if name == "<=>"
      return 1
    end
    0
  end

  def is_obj_type(t)
    if t.length > 4
      if t[0] == "o"
        if t[1] == "b"
          if t[2] == "j"
            if t[3] == "_"
              return 1
            end
          end
        end
      end
    end
    0
  end

  def type_is_pointer(t)
    if t == "int_array"
      return 1
    end
    if t == "str_array"
      return 1
    end
    if t == "str_int_hash"
      return 1
    end
    if t == "str_str_hash"
      return 1
    end
    if is_obj_type(t) == 1
      return 1
    end
    0
  end

  # ---- C type mapping ----
  def c_type(t)
    if t == "range"
      return "sp_Range"
    end
    if t == "int"
      return "mrb_int"
    end
    if t == "float"
      return "mrb_float"
    end
    if t == "bool"
      return "mrb_bool"
    end
    if t == "string"
      return "const char *"
    end
    if t == "void"
      return "mrb_int"
    end
    if t == "nil"
      return "mrb_int"
    end
    if t == "int_array"
      return "sp_IntArray *"
    end
    if t == "str_array"
      return "sp_StrArray *"
    end
    if t == "str_int_hash"
      return "sp_StrIntHash *"
    end
    if t == "str_str_hash"
      return "sp_StrStrHash *"
    end
    if t == "poly"
      return "sp_RbVal"
    end
    if is_obj_type(t) == 1
      cname = t[4, t.length - 4]
      return "sp_" + cname + " *"
    end
    "mrb_int"
  end

  def c_default_val(t)
    if t == "range"
      return "((sp_Range){0,0})"
    end
    if t == "int"
      return "0"
    end
    if t == "float"
      return "0.0"
    end
    if t == "bool"
      return "FALSE"
    end
    if t == "string"
      return "\"\""
    end
    if t == "void"
      return "0"
    end
    if t == "nil"
      return "0"
    end
    if t == "poly"
      return "sp_box_nil()"
    end
    if type_is_pointer(t) == 1
      return "NULL"
    end
    "0"
  end

  def sanitize_name(name)
    if name == "<=>"
      return "_cmp"
    end
    if name == "<="
      return "_le"
    end
    if name == ">="
      return "_ge"
    end
    if name == "<<"
      return "_lshift"
    end
    if name == ">>"
      return "_rshift"
    end
    if name == "<"
      return "_lt"
    end
    if name == ">"
      return "_gt"
    end
    if name == "+"
      return "_plus"
    end
    if name == "-"
      return "_minus"
    end
    if name == "*"
      return "_mul"
    end
    if name == "/"
      return "_div"
    end
    if name == "=="
      return "_eq_eq"
    end
    if name == "!="
      return "_neq"
    end
    if name == "[]"
      return "_aref"
    end
    if name == "[]="
      return "_aset"
    end
    result = ""
    i = 0
    while i < name.length
      ch = name[i]
      if ch == "?"
        result = result + "_p"
      else
        if ch == "!"
          result = result + "_bang"
        else
          if ch == "="
            result = result + "_eq"
          else
            result = result + ch
          end
        end
      end
      i = i + 1
    end
    result
  end

  def sanitize_ivar(name)
    if name.length > 0
      if name[0] == "@"
        return name[1, name.length - 1]
      end
    end
    name
  end

  # ---- Collection pass ----
  def collect_all
    root = @root_id
    if @nd_type[root] != "ProgramNode"
      return
    end
    stmts = get_body_stmts(root)

    # Pass 1: classes
    i = 0
    while i < stmts.length
      sid = stmts[i]
      if @nd_type[sid] == "ClassNode"
        collect_class(sid)
      end
      i = i + 1
    end

    # Pass 2: top-level methods, constants, and modules
    i = 0
    while i < stmts.length
      sid = stmts[i]
      if @nd_type[sid] == "DefNode"
        collect_toplevel_method(sid)
      end
      if @nd_type[sid] == "ConstantWriteNode"
        collect_constant(sid)
      end
      if @nd_type[sid] == "ModuleNode"
        collect_module(sid)
      end
      i = i + 1
    end

    # Pass 3: infer return types
    infer_all_returns
  end

  def collect_class(nid)
    ci = @cls_names.length
    cname = ""
    cp = @nd_constant_path[nid]
    if cp >= 0
      cname = @nd_name[cp]
    end
    parent = ""
    sp = @nd_superclass[nid]
    if sp >= 0
      parent = @nd_name[sp]
    end

    @cls_names.push(cname)
    @cls_parents.push(parent)
    @cls_ivar_names.push("")
    @cls_ivar_types.push("")
    @cls_meth_names.push("")
    @cls_meth_params.push("")
    @cls_meth_ptypes.push("")
    @cls_meth_returns.push("")
    @cls_meth_bodies.push("")
    @cls_meth_defaults.push("")
    @cls_attr_readers.push("")
    @cls_attr_writers.push("")
    @cls_cmeth_names.push("")
    @cls_cmeth_params.push("")
    @cls_cmeth_ptypes.push("")
    @cls_cmeth_returns.push("")
    @cls_cmeth_bodies.push("")
    @cls_meth_has_yield.push("")
    @needs_gc = 1

    # Collect class body
    body = @nd_body[nid]
    if body < 0
      return
    end
    body_stmts = get_stmts(body)
    j = 0
    while j < body_stmts.length
      sid = body_stmts[j]
      if @nd_type[sid] == "DefNode"
        collect_class_method(ci, sid)
      end
      if @nd_type[sid] == "CallNode"
        collect_attr_call(ci, sid)
      end
      j = j + 1
    end

    # Collect ivars
    collect_ivars(ci)
  end

  def collect_class_method(ci, nid)
    mname = @nd_name[nid]
    body_id = @nd_body[nid]

    # Check for class method (def self.xxx)
    if @nd_receiver[nid] >= 0
      if @nd_type[@nd_receiver[nid]] == "SelfNode"
        # Class method
        params_str = collect_params_str(nid)
        ptypes_str = collect_ptypes_str(nid, ci)
        defaults_str = collect_defaults_str(nid)
        append_cls_cmeth(ci, mname, params_str, ptypes_str, "int", body_id)
        return
      end
    end

    params_str = collect_params_str(nid)
    ptypes_str = collect_ptypes_str(nid, ci)
    defaults_str = collect_defaults_str(nid)
    has_y = body_has_yield(body_id)
    append_cls_meth(ci, mname, params_str, ptypes_str, "int", body_id, defaults_str)
    # Track yield info
    if @cls_meth_has_yield[ci] != ""
      @cls_meth_has_yield[ci] = @cls_meth_has_yield[ci] + ";" + has_y.to_s
    else
      @cls_meth_has_yield[ci] = has_y.to_s
    end
    return
  end

  def collect_params_str(nid)
    params = @nd_parameters[nid]
    if params < 0
      return ""
    end
    reqs = parse_id_list(@nd_requireds[params])
    opts = parse_id_list(@nd_optionals[params])
    kws = parse_id_list(@nd_keywords[params])
    result = ""
    k = 0
    while k < reqs.length
      if result != ""
        result = result + ","
      end
      result = result + @nd_name[reqs[k]]
      k = k + 1
    end
    k = 0
    while k < opts.length
      if result != ""
        result = result + ","
      end
      result = result + @nd_name[opts[k]]
      k = k + 1
    end
    k = 0
    while k < kws.length
      if result != ""
        result = result + ","
      end
      result = result + @nd_name[kws[k]]
      k = k + 1
    end
    # Rest param (splat)
    rest = @nd_rest[params]
    if rest >= 0
      if @nd_type[rest] == "RestParameterNode"
        if result != ""
          result = result + ","
        end
        result = result + @nd_name[rest]
      end
    end
    result
  end

  def collect_ptypes_str(nid, ci)
    params = @nd_parameters[nid]
    if params < 0
      return ""
    end
    reqs = parse_id_list(@nd_requireds[params])
    opts = parse_id_list(@nd_optionals[params])
    kws = parse_id_list(@nd_keywords[params])
    result = ""
    k = 0
    while k < reqs.length
      if result != ""
        result = result + ","
      end
      result = result + "int"
      k = k + 1
    end
    k = 0
    while k < opts.length
      if result != ""
        result = result + ","
      end
      # Infer from default value
      def_id = @nd_expression[opts[k]]
      if def_id >= 0
        result = result + infer_type(def_id)
      else
        result = result + "int"
      end
      k = k + 1
    end
    k = 0
    while k < kws.length
      if result != ""
        result = result + ","
      end
      # Infer from default value
      def_id = @nd_expression[kws[k]]
      if def_id >= 0
        result = result + infer_type(def_id)
      else
        result = result + "int"
      end
      k = k + 1
    end
    # Rest param (splat)
    rest = @nd_rest[params]
    if rest >= 0
      if @nd_type[rest] == "RestParameterNode"
        if result != ""
          result = result + ","
        end
        result = result + "int_array"
      end
    end
    result
  end

  def collect_defaults_str(nid)
    params = @nd_parameters[nid]
    if params < 0
      return ""
    end
    reqs = parse_id_list(@nd_requireds[params])
    opts = parse_id_list(@nd_optionals[params])
    kws = parse_id_list(@nd_keywords[params])
    result = ""
    k = 0
    while k < reqs.length
      if result != ""
        result = result + ","
      end
      result = result + "-1"
      k = k + 1
    end
    k = 0
    while k < opts.length
      if result != ""
        result = result + ","
      end
      def_id = @nd_expression[opts[k]]
      if def_id >= 0
        result = result + def_id.to_s
      else
        result = result + "-1"
      end
      k = k + 1
    end
    k = 0
    while k < kws.length
      if result != ""
        result = result + ","
      end
      def_id = @nd_expression[kws[k]]
      if def_id >= 0
        result = result + def_id.to_s
      else
        result = result + "-1"
      end
      k = k + 1
    end
    # Rest param
    rest = @nd_rest[params]
    if rest >= 0
      if @nd_type[rest] == "RestParameterNode"
        if result != ""
          result = result + ","
        end
        result = result + "-1"
      end
    end
    result
  end

  def append_cls_meth(ci, name, params, ptypes, ret, body_id, defaults)
    if @cls_meth_names[ci] != ""
      @cls_meth_names[ci] = @cls_meth_names[ci] + ";" + name
      @cls_meth_params[ci] = @cls_meth_params[ci] + "|" + params
      @cls_meth_ptypes[ci] = @cls_meth_ptypes[ci] + "|" + ptypes
      @cls_meth_returns[ci] = @cls_meth_returns[ci] + ";" + ret
      @cls_meth_bodies[ci] = @cls_meth_bodies[ci] + ";" + body_id.to_s
      @cls_meth_defaults[ci] = @cls_meth_defaults[ci] + "|" + defaults
    else
      @cls_meth_names[ci] = name
      @cls_meth_params[ci] = params
      @cls_meth_ptypes[ci] = ptypes
      @cls_meth_returns[ci] = ret
      @cls_meth_bodies[ci] = body_id.to_s
      @cls_meth_defaults[ci] = defaults
    end
  end

  def append_cls_cmeth(ci, name, params, ptypes, ret, body_id)
    if @cls_cmeth_names[ci] != ""
      @cls_cmeth_names[ci] = @cls_cmeth_names[ci] + ";" + name
      @cls_cmeth_params[ci] = @cls_cmeth_params[ci] + "|" + params
      @cls_cmeth_ptypes[ci] = @cls_cmeth_ptypes[ci] + "|" + ptypes
      @cls_cmeth_returns[ci] = @cls_cmeth_returns[ci] + ";" + ret
      @cls_cmeth_bodies[ci] = @cls_cmeth_bodies[ci] + ";" + body_id.to_s
    else
      @cls_cmeth_names[ci] = name
      @cls_cmeth_params[ci] = params
      @cls_cmeth_ptypes[ci] = ptypes
      @cls_cmeth_returns[ci] = ret
      @cls_cmeth_bodies[ci] = body_id.to_s
    end
  end

  def collect_attr_call(ci, nid)
    mname = @nd_name[nid]
    args_id = @nd_arguments[nid]
    if args_id < 0
      return
    end
    arg_ids = get_args(args_id)
    if mname == "attr_accessor"
      k = 0
      while k < arg_ids.length
        aname = @nd_content[arg_ids[k]]
        append_attr_reader(ci, aname)
        append_attr_writer(ci, aname)
        k = k + 1
      end
    end
    if mname == "attr_reader"
      k = 0
      while k < arg_ids.length
        aname = @nd_content[arg_ids[k]]
        append_attr_reader(ci, aname)
        k = k + 1
      end
    end
    if mname == "attr_writer"
      k = 0
      while k < arg_ids.length
        aname = @nd_content[arg_ids[k]]
        append_attr_writer(ci, aname)
        k = k + 1
      end
    end
  end

  def append_attr_reader(ci, name)
    if @cls_attr_readers[ci] != ""
      @cls_attr_readers[ci] = @cls_attr_readers[ci] + ";" + name
    else
      @cls_attr_readers[ci] = name
    end
  end

  def append_attr_writer(ci, name)
    if @cls_attr_writers[ci] != ""
      @cls_attr_writers[ci] = @cls_attr_writers[ci] + ";" + name
    else
      @cls_attr_writers[ci] = name
    end
  end

  def collect_ivars(ci)
    # Scan all methods for ivar writes
    meths = @cls_meth_bodies[ci].split(";")
    j = 0
    while j < meths.length
      bid = meths[j].to_i
      if bid >= 0
        scan_ivars(ci, bid)
      end
      j = j + 1
    end
    # Add ivars from attr_readers/writers that might not have explicit writes
    readers = @cls_attr_readers[ci].split(";")
    j = 0
    while j < readers.length
      iname = "@" + readers[j]
      if ivar_exists(ci, iname) == 0
        add_ivar(ci, iname, "int")
      end
      j = j + 1
    end
    writers = @cls_attr_writers[ci].split(";")
    j = 0
    while j < writers.length
      iname = "@" + writers[j]
      if ivar_exists(ci, iname) == 0
        add_ivar(ci, iname, "int")
      end
      j = j + 1
    end
  end

  def update_ivar_type(ci, iname, new_type)
    names = @cls_ivar_names[ci].split(";")
    types = @cls_ivar_types[ci].split(";")
    k = 0
    while k < names.length
      if names[k] == iname
        if k < types.length
          if types[k] == "int"
            types[k] = new_type
            @cls_ivar_types[ci] = join_sep(types, ";")
          end
          if types[k] == "nil"
            types[k] = new_type
            @cls_ivar_types[ci] = join_sep(types, ";")
          end
        end
        return
      end
      k = k + 1
    end
  end

  def ivar_exists(ci, iname)
    names = @cls_ivar_names[ci].split(";")
    k = 0
    while k < names.length
      if names[k] == iname
        return 1
      end
      k = k + 1
    end
    0
  end

  def add_ivar(ci, iname, itype)
    if @cls_ivar_names[ci] != ""
      @cls_ivar_names[ci] = @cls_ivar_names[ci] + ";" + iname
      @cls_ivar_types[ci] = @cls_ivar_types[ci] + ";" + itype
    else
      @cls_ivar_names[ci] = iname
      @cls_ivar_types[ci] = itype
    end
  end

  def scan_ivars(ci, nid)
    if nid < 0
      return
    end
    if @nd_type[nid] == "InstanceVariableWriteNode"
      iname = @nd_name[nid]
      if ivar_exists(ci, iname) == 0
        vtype = infer_ivar_init_type(@nd_expression[nid])
        add_ivar(ci, iname, vtype)
      else
        # Update type if current type is int (default/nil) and new type is better
        expr = @nd_expression[nid]
        if expr >= 0
          if @nd_type[expr] != "NilNode"
            vtype = infer_ivar_init_type(expr)
            if vtype != "int"
              update_ivar_type(ci, iname, vtype)
            end
          end
        end
      end
    end
    if @nd_type[nid] == "InstanceVariableOperatorWriteNode"
      iname = @nd_name[nid]
      if ivar_exists(ci, iname) == 0
        add_ivar(ci, iname, "int")
      end
    end
    # Recurse into children
    scan_ivars_children(ci, nid)
  end

  def scan_ivars_children(ci, nid)
    if @nd_body[nid] >= 0
      scan_ivars(ci, @nd_body[nid])
    end
    stmts = parse_id_list(@nd_stmts[nid])
    k = 0
    while k < stmts.length
      scan_ivars(ci, stmts[k])
      k = k + 1
    end
    if @nd_expression[nid] >= 0
      scan_ivars(ci, @nd_expression[nid])
    end
    if @nd_predicate[nid] >= 0
      scan_ivars(ci, @nd_predicate[nid])
    end
    if @nd_subsequent[nid] >= 0
      scan_ivars(ci, @nd_subsequent[nid])
    end
    if @nd_else_clause[nid] >= 0
      scan_ivars(ci, @nd_else_clause[nid])
    end
    if @nd_receiver[nid] >= 0
      scan_ivars(ci, @nd_receiver[nid])
    end
    if @nd_arguments[nid] >= 0
      scan_ivars(ci, @nd_arguments[nid])
    end
    args = parse_id_list(@nd_args[nid])
    k = 0
    while k < args.length
      scan_ivars(ci, args[k])
      k = k + 1
    end
    conds = parse_id_list(@nd_conditions[nid])
    k = 0
    while k < conds.length
      scan_ivars(ci, conds[k])
      k = k + 1
    end
    if @nd_left[nid] >= 0
      scan_ivars(ci, @nd_left[nid])
    end
    if @nd_right[nid] >= 0
      scan_ivars(ci, @nd_right[nid])
    end
    if @nd_block[nid] >= 0
      scan_ivars(ci, @nd_block[nid])
    end
    elems = parse_id_list(@nd_elements[nid])
    k = 0
    while k < elems.length
      scan_ivars(ci, elems[k])
      k = k + 1
    end
  end

  def infer_ivar_init_type(nid)
    if nid < 0
      return "int"
    end
    t = @nd_type[nid]
    if t == "NilNode"
      return "nil"
    end
    if t == "IntegerNode"
      return "int"
    end
    if t == "FloatNode"
      return "float"
    end
    if t == "StringNode"
      return "string"
    end
    if t == "SymbolNode"
      return "string"
    end
    if t == "TrueNode"
      return "bool"
    end
    if t == "FalseNode"
      return "bool"
    end
    if t == "ArrayNode"
      return infer_array_elem_type(nid)
    end
    if t == "HashNode"
      return infer_hash_val_type(nid)
    end
    if t == "CallNode"
      mname = @nd_name[nid]
      if mname == "to_a"
        return "int_array"
      end
      if mname == "split"
        return "str_array"
      end
      if mname == "new"
        r = @nd_receiver[nid]
        if r >= 0
          if @nd_type[r] == "ConstantReadNode"
            return "obj_" + @nd_name[r]
          end
        end
      end
    end
    if t == "LocalVariableReadNode"
      vt = find_var_type(@nd_name[nid])
      if vt != ""
        return vt
      end
    end
    "int"
  end

  def collect_toplevel_method(nid)
    mname = @nd_name[nid]
    body_id = @nd_body[nid]
    params_str = collect_params_str(nid)
    ptypes_str = ""
    defaults_str = collect_defaults_str(nid)

    # Infer param types from defaults
    params = @nd_parameters[nid]
    if params >= 0
      reqs = parse_id_list(@nd_requireds[params])
      opts = parse_id_list(@nd_optionals[params])
      kws = parse_id_list(@nd_keywords[params])
      k = 0
      while k < reqs.length
        if ptypes_str != ""
          ptypes_str = ptypes_str + ","
        end
        ptypes_str = ptypes_str + "int"
        k = k + 1
      end
      k = 0
      while k < opts.length
        if ptypes_str != ""
          ptypes_str = ptypes_str + ","
        end
        def_id = @nd_expression[opts[k]]
        if def_id >= 0
          ptypes_str = ptypes_str + infer_type(def_id)
        else
          ptypes_str = ptypes_str + "int"
        end
        k = k + 1
      end
      k = 0
      while k < kws.length
        if ptypes_str != ""
          ptypes_str = ptypes_str + ","
        end
        def_id = @nd_expression[kws[k]]
        if def_id >= 0
          ptypes_str = ptypes_str + infer_type(def_id)
        else
          ptypes_str = ptypes_str + "int"
        end
        k = k + 1
      end
      # Rest param (splat)
      rest = @nd_rest[params]
      if rest >= 0
        if @nd_type[rest] == "RestParameterNode"
          if ptypes_str != ""
            ptypes_str = ptypes_str + ","
          end
          ptypes_str = ptypes_str + "int_array"
        end
      end
    end

    @meth_names.push(mname)
    @meth_param_names.push(params_str)
    @meth_param_types.push(ptypes_str)
    @meth_return_types.push("int")
    @meth_body_ids.push(body_id)
    @meth_has_defaults.push(defaults_str)
    @meth_has_yield.push(body_has_yield(body_id))
  end

  def collect_module(nid)
    mname = ""
    cp = @nd_constant_path[nid]
    if cp >= 0
      mname = @nd_name[cp]
    end
    body = @nd_body[nid]
    if body < 0
      return
    end
    body_stmts = get_stmts(body)
    j = 0
    while j < body_stmts.length
      sid = body_stmts[j]
      if @nd_type[sid] == "ConstantWriteNode"
        cname = mname + "_" + @nd_name[sid]
        expr_id = @nd_expression[sid]
        ct = "int"
        if expr_id >= 0
          ct = infer_type(expr_id)
        end
        @const_names.push(cname)
        @const_types.push(ct)
        @const_expr_ids.push(expr_id)
      end
      if @nd_type[sid] == "DefNode"
        collect_toplevel_method(sid)
      end
      j = j + 1
    end
  end

  def collect_constant(nid)
    # Check for Struct.new(:x, :y)
    expr_id = @nd_expression[nid]
    if expr_id >= 0
      if @nd_type[expr_id] == "CallNode"
        if @nd_name[expr_id] == "new"
          sr = @nd_receiver[expr_id]
          if sr >= 0
            if @nd_type[sr] == "ConstantReadNode"
              if @nd_name[sr] == "Struct"
                collect_struct_class(@nd_name[nid], expr_id)
                return
              end
            end
          end
        end
      end
    end
    @const_names.push(@nd_name[nid])
    ct = "int"
    if expr_id >= 0
      ct = infer_type(expr_id)
    end
    @const_types.push(ct)
    @const_expr_ids.push(expr_id)
  end

  def collect_struct_class(cname, call_nid)
    # Generate a synthetic class from Struct.new(:field1, :field2, ...)
    ci = @cls_names.length
    @cls_names.push(cname)
    @cls_parents.push("")
    @cls_ivar_names.push("")
    @cls_ivar_types.push("")
    @cls_meth_names.push("")
    @cls_meth_params.push("")
    @cls_meth_ptypes.push("")
    @cls_meth_returns.push("")
    @cls_meth_bodies.push("")
    @cls_meth_defaults.push("")
    @cls_attr_readers.push("")
    @cls_attr_writers.push("")
    @cls_cmeth_names.push("")
    @cls_cmeth_params.push("")
    @cls_cmeth_ptypes.push("")
    @cls_cmeth_returns.push("")
    @cls_cmeth_bodies.push("")
    @cls_meth_has_yield.push("")
    @needs_gc = 1

    # Get field names from symbol args (skip keyword_init hash)
    args_id = @nd_arguments[call_nid]
    field_names = "".split(",")
    if args_id >= 0
      aids = get_args(args_id)
      k = 0
      while k < aids.length
        # Skip KeywordHashNode (keyword_init: true)
        if @nd_type[aids[k]] == "KeywordHashNode"
          k = k + 1
          next
        end
        fname = @nd_content[aids[k]]
        if fname != ""
          field_names.push(fname)
          # Add ivar
          iname = "@" + fname
          add_ivar(ci, iname, "int")
          # Add reader/writer
          append_attr_reader(ci, fname)
          append_attr_writer(ci, fname)
        end
        k = k + 1
      end
    end

    # Generate initialize method with params matching fields
    init_params = join_sep(field_names, ",")
    init_ptypes = ""
    k = 0
    while k < field_names.length
      if k > 0
        init_ptypes = init_ptypes + ","
      end
      init_ptypes = init_ptypes + "int"
      k = k + 1
    end
    # For struct, we don't have a body node - the constructor is synthetic
    # We'll handle this specially in emit_constructor
    append_cls_meth(ci, "initialize", init_params, init_ptypes, "void", -1, "")
    # Mark yield info
    @cls_meth_has_yield[ci] = "0"

    # Store struct info for synthetic constructor generation
    # We'll use a special marker in the body id (-2 = synthetic struct)
    bodies = @cls_meth_bodies[ci].split(";")
    if bodies.length > 0
      bodies[0] = "-2"
      @cls_meth_bodies[ci] = join_sep(bodies, ";")
    end
  end

  # ---- Yield detection ----
  def body_has_yield(nid)
    if nid < 0
      return 0
    end
    if @nd_type[nid] == "YieldNode"
      return 1
    end
    if @nd_type[nid] == "CallNode"
      if @nd_name[nid] == "block_given?"
        return 1
      end
    end
    # Don't recurse into nested DefNode (that's a different method)
    if @nd_type[nid] == "DefNode"
      return 0
    end
    if @nd_type[nid] == "BlockNode"
      # Don't look inside blocks of other calls for yield
      # Actually we do - yield inside a block still belongs to enclosing method
    end
    # Recurse children
    if @nd_body[nid] >= 0
      if body_has_yield(@nd_body[nid]) == 1
        return 1
      end
    end
    stmts = parse_id_list(@nd_stmts[nid])
    k = 0
    while k < stmts.length
      if body_has_yield(stmts[k]) == 1
        return 1
      end
      k = k + 1
    end
    if @nd_expression[nid] >= 0
      if body_has_yield(@nd_expression[nid]) == 1
        return 1
      end
    end
    if @nd_predicate[nid] >= 0
      if body_has_yield(@nd_predicate[nid]) == 1
        return 1
      end
    end
    if @nd_subsequent[nid] >= 0
      if body_has_yield(@nd_subsequent[nid]) == 1
        return 1
      end
    end
    if @nd_else_clause[nid] >= 0
      if body_has_yield(@nd_else_clause[nid]) == 1
        return 1
      end
    end
    if @nd_left[nid] >= 0
      if body_has_yield(@nd_left[nid]) == 1
        return 1
      end
    end
    if @nd_right[nid] >= 0
      if body_has_yield(@nd_right[nid]) == 1
        return 1
      end
    end
    if @nd_block[nid] >= 0
      if body_has_yield(@nd_block[nid]) == 1
        return 1
      end
    end
    conds = parse_id_list(@nd_conditions[nid])
    k = 0
    while k < conds.length
      if body_has_yield(conds[k]) == 1
        return 1
      end
      k = k + 1
    end
    args = parse_id_list(@nd_args[nid])
    k = 0
    while k < args.length
      if body_has_yield(args[k]) == 1
        return 1
      end
      k = k + 1
    end
    if @nd_arguments[nid] >= 0
      if body_has_yield(@nd_arguments[nid]) == 1
        return 1
      end
    end
    if @nd_receiver[nid] >= 0
      if body_has_yield(@nd_receiver[nid]) == 1
        return 1
      end
    end
    0
  end

  # ---- Return type inference ----
  def infer_constructor_types
    # Scan AST for ClassName.new(args) calls and infer param types
    scan_new_calls(@root_id)
  end

  def scan_new_calls(nid)
    if nid < 0
      return
    end
    if @nd_type[nid] == "CallNode"
      # Also infer top-level method param types from call sites
      mname = @nd_name[nid]
      if @nd_receiver[nid] < 0
        mi = find_method_idx(mname)
        if mi >= 0
          args_id = @nd_arguments[nid]
          if args_id >= 0
            arg_ids = get_args(args_id)
            ptypes = @meth_param_types[mi].split(",")
            pnames = @meth_param_names[mi].split(",")
            # Handle keyword hash args
            ak = 0
            while ak < arg_ids.length
              if @nd_type[arg_ids[ak]] == "KeywordHashNode"
                elems = parse_id_list(@nd_elements[arg_ids[ak]])
                ek = 0
                while ek < elems.length
                  if @nd_type[elems[ek]] == "AssocNode"
                    key_id = @nd_key[elems[ek]]
                    if key_id >= 0
                      kname = ""
                      if @nd_type[key_id] == "SymbolNode"
                        kname = @nd_content[key_id]
                      end
                      at = infer_type(@nd_expression[elems[ek]])
                      # Find matching param name
                      pi = 0
                      while pi < pnames.length
                        if pnames[pi] == kname
                          if pi < ptypes.length
                            if ptypes[pi] == "int"
                              if at != "int"
                                ptypes[pi] = at
                              end
                            end
                          end
                        end
                        pi = pi + 1
                      end
                    end
                  end
                  ek = ek + 1
                end
              else
                at = infer_type(arg_ids[ak])
                if ak < ptypes.length
                  if ptypes[ak] == "int"
                    if at != "int"
                      ptypes[ak] = at
                    end
                  end
                end
              end
              ak = ak + 1
            end
            @meth_param_types[mi] = join_sep(ptypes, ",")
          end
        end
      end
      if @nd_name[nid] == "new"
        recv = @nd_receiver[nid]
        if recv >= 0
          if @nd_type[recv] == "ConstantReadNode"
            cname = @nd_name[recv]
            ci = find_class_idx(cname)
            if ci >= 0
              init_ci = find_init_class(ci)
              if init_ci >= 0
                init_idx = cls_find_method_direct(init_ci, "initialize")
                if init_idx >= 0
                  args_id = @nd_arguments[nid]
                  if args_id >= 0
                    arg_ids = get_args(args_id)
                    all_ptypes = @cls_meth_ptypes[init_ci].split("|")
                    all_params = @cls_meth_params[init_ci].split("|")
                    if init_idx < all_ptypes.length
                      ptypes = all_ptypes[init_idx].split(",")
                      pnames = []
                      if init_idx < all_params.length
                        pnames = all_params[init_idx].split(",")
                      end
                      k = 0
                      while k < arg_ids.length
                        if @nd_type[arg_ids[k]] == "KeywordHashNode"
                          # Handle keyword args
                          elems = parse_id_list(@nd_elements[arg_ids[k]])
                          ek = 0
                          while ek < elems.length
                            if @nd_type[elems[ek]] == "AssocNode"
                              key_id = @nd_key[elems[ek]]
                              if key_id >= 0
                                kname = ""
                                if @nd_type[key_id] == "SymbolNode"
                                  kname = @nd_content[key_id]
                                end
                                at = infer_type(@nd_expression[elems[ek]])
                                pi = 0
                                while pi < pnames.length
                                  if pnames[pi] == kname
                                    if pi < ptypes.length
                                      if ptypes[pi] == "int"
                                        if at != "int"
                                          ptypes[pi] = at
                                        end
                                      end
                                    end
                                  end
                                  pi = pi + 1
                                end
                              end
                            end
                            ek = ek + 1
                          end
                        else
                          at = infer_type(arg_ids[k])
                          if k < ptypes.length
                            if ptypes[k] == "int"
                              if at != "int"
                                ptypes[k] = at
                              end
                            end
                          end
                        end
                        k = k + 1
                      end
                      all_ptypes[init_idx] = join_sep(ptypes, ",")
                      @cls_meth_ptypes[init_ci] = join_sep(all_ptypes, "|")
                    end
                  end
                end
              end
            end
          end
        end
      end
      # Also infer method param types from method/operator calls on objects
      if @nd_receiver[nid] >= 0
        rt = infer_type(@nd_receiver[nid])
        if is_obj_type(rt) == 1
          cname = rt[4, rt.length - 4]
          ci = find_class_idx(cname)
          if ci >= 0
            midx = cls_find_method_direct(ci, mname)
            if midx >= 0
              args_id = @nd_arguments[nid]
              if args_id >= 0
                arg_ids = get_args(args_id)
                all_ptypes = @cls_meth_ptypes[ci].split("|")
                if midx < all_ptypes.length
                  ptypes = all_ptypes[midx].split(",")
                  kk = 0
                  while kk < arg_ids.length
                    at = infer_type(arg_ids[kk])
                    if kk < ptypes.length
                      if ptypes[kk] == "int"
                        if at != "int"
                          ptypes[kk] = at
                        end
                      end
                    end
                    kk = kk + 1
                  end
                  all_ptypes[midx] = join_sep(ptypes, ",")
                  @cls_meth_ptypes[ci] = join_sep(all_ptypes, "|")
                end
              end
            end
          end
        end
      end
    end
    # Recurse into children
    if @nd_body[nid] >= 0
      scan_new_calls(@nd_body[nid])
    end
    stmts = parse_id_list(@nd_stmts[nid])
    k = 0
    while k < stmts.length
      scan_new_calls(stmts[k])
      k = k + 1
    end
    if @nd_receiver[nid] >= 0
      scan_new_calls(@nd_receiver[nid])
    end
    if @nd_arguments[nid] >= 0
      scan_new_calls(@nd_arguments[nid])
    end
    args = parse_id_list(@nd_args[nid])
    k = 0
    while k < args.length
      scan_new_calls(args[k])
      k = k + 1
    end
    if @nd_expression[nid] >= 0
      scan_new_calls(@nd_expression[nid])
    end
    if @nd_predicate[nid] >= 0
      scan_new_calls(@nd_predicate[nid])
    end
    if @nd_subsequent[nid] >= 0
      scan_new_calls(@nd_subsequent[nid])
    end
    if @nd_else_clause[nid] >= 0
      scan_new_calls(@nd_else_clause[nid])
    end
    if @nd_left[nid] >= 0
      scan_new_calls(@nd_left[nid])
    end
    if @nd_right[nid] >= 0
      scan_new_calls(@nd_right[nid])
    end
    if @nd_block[nid] >= 0
      scan_new_calls(@nd_block[nid])
    end
    elems = parse_id_list(@nd_elements[nid])
    k = 0
    while k < elems.length
      scan_new_calls(elems[k])
      k = k + 1
    end
    conds = parse_id_list(@nd_conditions[nid])
    k = 0
    while k < conds.length
      scan_new_calls(conds[k])
      k = k + 1
    end
  end

  def update_ivar_types_from_params
    # Special case: synthetic struct constructors - ivars match params directly
    i = 0
    while i < @cls_names.length
      init_idx2 = cls_find_method_direct(i, "initialize")
      if init_idx2 >= 0
        bodies = @cls_meth_bodies[i].split(";")
        if init_idx2 < bodies.length
          if bodies[init_idx2].to_i == -2
            # Synthetic struct - update ivar types from init param types
            all_params = @cls_meth_params[i].split("|")
            all_ptypes = @cls_meth_ptypes[i].split("|")
            pnames = []
            ptypes = []
            if init_idx2 < all_params.length
              pnames = all_params[init_idx2].split(",")
            end
            if init_idx2 < all_ptypes.length
              ptypes = all_ptypes[init_idx2].split(",")
            end
            pk = 0
            while pk < pnames.length
              iname = "@" + pnames[pk]
              if pk < ptypes.length
                if ptypes[pk] != "int"
                  update_ivar_type(i, iname, ptypes[pk])
                end
              end
              pk = pk + 1
            end
          end
        end
      end
      i = i + 1
    end
    # For each class method, if it assigns @ivar = param, update ivar type from param type
    i = 0
    while i < @cls_names.length
      mnames = @cls_meth_names[i].split(";")
      mi = 0
      while mi < mnames.length
        init_idx = mi
        all_params = @cls_meth_params[i].split("|")
        all_ptypes = @cls_meth_ptypes[i].split("|")
        pnames = []
        ptypes = []
        if init_idx < all_params.length
          pnames = all_params[init_idx].split(",")
        end
        if init_idx < all_ptypes.length
          ptypes = all_ptypes[init_idx].split(",")
        end
        bodies = @cls_meth_bodies[i].split(";")
        bid = -1
        if init_idx < bodies.length
          bid = bodies[init_idx].to_i
        end
        if bid >= 0
          stmts = get_stmts(bid)
          k = 0
          while k < stmts.length
            sid = stmts[k]
            if @nd_type[sid] == "InstanceVariableWriteNode"
              expr = @nd_expression[sid]
              if expr >= 0
                if @nd_type[expr] == "LocalVariableReadNode"
                  pname = @nd_name[expr]
                  # Find param index
                  pi = 0
                  while pi < pnames.length
                    if pnames[pi] == pname
                      if pi < ptypes.length
                        # Update ivar type
                        iname = @nd_name[sid]
                        ivar_names = @cls_ivar_names[i].split(";")
                        ivar_types = @cls_ivar_types[i].split(";")
                        ij = 0
                        while ij < ivar_names.length
                          if ivar_names[ij] == iname
                            if ivar_types[ij] == "int"
                              ivar_types[ij] = ptypes[pi]
                            end
                            if ivar_types[ij] == "nil"
                              ivar_types[ij] = ptypes[pi]
                            end
                          end
                          ij = ij + 1
                        end
                        @cls_ivar_types[i] = join_sep(ivar_types, ";")
                      end
                    end
                    pi = pi + 1
                  end
                end
              end
            end
            k = k + 1
          end
        end
        mi = mi + 1
      end
      i = i + 1
    end
  end

  def infer_cls_meth_param_from_body
    # For each class method, if a param is used as param.attr_reader where attr_reader
    # belongs to this class, infer param type as this class.
    ci = 0
    while ci < @cls_names.length
      readers = @cls_attr_readers[ci].split(";")
      if readers.length > 0
        mnames = @cls_meth_names[ci].split(";")
        all_params = @cls_meth_params[ci].split("|")
        all_ptypes = @cls_meth_ptypes[ci].split("|")
        bodies = @cls_meth_bodies[ci].split(";")
        j = 0
        while j < mnames.length
          if mnames[j] != "initialize"
            pnames = []
            ptypes = []
            if j < all_params.length
              pnames = all_params[j].split(",")
            end
            if j < all_ptypes.length
              ptypes = all_ptypes[j].split(",")
            end
            bid = -1
            if j < bodies.length
              bid = bodies[j].to_i
            end
            if bid >= 0
              pk = 0
              while pk < pnames.length
                if pk < ptypes.length
                  if ptypes[pk] == "int"
                    if param_calls_reader(bid, pnames[pk], readers) == 1
                      ptypes[pk] = "obj_" + @cls_names[ci]
                      all_ptypes[j] = join_sep(ptypes, ",")
                      @cls_meth_ptypes[ci] = join_sep(all_ptypes, "|")
                    end
                  end
                end
                pk = pk + 1
              end
            end
          end
          j = j + 1
        end
      end
      ci = ci + 1
    end
  end

  def param_calls_reader(nid, pname, readers)
    if nid < 0
      return 0
    end
    if @nd_type[nid] == "CallNode"
      recv = @nd_receiver[nid]
      if recv >= 0
        if @nd_type[recv] == "LocalVariableReadNode"
          if @nd_name[recv] == pname
            mname = @nd_name[nid]
            ri = 0
            while ri < readers.length
              if readers[ri] == mname
                return 1
              end
              ri = ri + 1
            end
          end
        end
      end
    end
    # Recurse
    if @nd_body[nid] >= 0
      if param_calls_reader(@nd_body[nid], pname, readers) == 1
        return 1
      end
    end
    stmts = parse_id_list(@nd_stmts[nid])
    k = 0
    while k < stmts.length
      if param_calls_reader(stmts[k], pname, readers) == 1
        return 1
      end
      k = k + 1
    end
    if @nd_expression[nid] >= 0
      if param_calls_reader(@nd_expression[nid], pname, readers) == 1
        return 1
      end
    end
    if @nd_left[nid] >= 0
      if param_calls_reader(@nd_left[nid], pname, readers) == 1
        return 1
      end
    end
    if @nd_right[nid] >= 0
      if param_calls_reader(@nd_right[nid], pname, readers) == 1
        return 1
      end
    end
    if @nd_arguments[nid] >= 0
      if param_calls_reader(@nd_arguments[nid], pname, readers) == 1
        return 1
      end
    end
    args = parse_id_list(@nd_args[nid])
    k = 0
    while k < args.length
      if param_calls_reader(args[k], pname, readers) == 1
        return 1
      end
      k = k + 1
    end
    if @nd_receiver[nid] >= 0
      if param_calls_reader(@nd_receiver[nid], pname, readers) == 1
        return 1
      end
    end
    0
  end

  def infer_ivar_types_from_writers
    # Set up main scope for type inference
    push_scope
    stmts = get_body_stmts(@root_id)
    lnames = "".split(",")
    ltypes = "".split(",")
    empty_p = "".split(",")
    i = 0
    while i < stmts.length
      sid = stmts[i]
      if @nd_type[sid] != "DefNode"
        if @nd_type[sid] != "ClassNode"
          if @nd_type[sid] != "ConstantWriteNode"
            if @nd_type[sid] != "ModuleNode"
              scan_locals(sid, lnames, ltypes, empty_p)
            end
          end
        end
      end
      i = i + 1
    end
    k = 0
    while k < lnames.length
      declare_var(lnames[k], ltypes[k])
      k = k + 1
    end
    # Also scan inside method bodies
    i = 0
    while i < @meth_names.length
      push_scope
      pnames = @meth_param_names[i].split(",")
      ptypes = @meth_param_types[i].split(",")
      j = 0
      while j < pnames.length
        pt = "int"
        if j < ptypes.length
          pt = ptypes[j]
        end
        declare_var(pnames[j], pt)
        j = j + 1
      end
      if @meth_body_ids[i] >= 0
        ml = []
        mt = []
        scan_locals(@meth_body_ids[i], ml, mt, pnames)
        lk = 0
        while lk < ml.length
          declare_var(ml[lk], mt[lk])
          lk = lk + 1
        end
        scan_writer_calls(@meth_body_ids[i])
      end
      pop_scope
      i = i + 1
    end
    # Scan main-level code
    scan_writer_calls(@root_id)
    pop_scope
  end

  def scan_writer_calls(nid)
    if nid < 0
      return
    end
    if @nd_type[nid] == "CallNode"
      mname = @nd_name[nid]
      recv = @nd_receiver[nid]
      if recv >= 0
        if mname.length > 1
          if mname[mname.length - 1] == "="
            bname = mname[0, mname.length - 1]
            rt = infer_type(recv)
            if is_obj_type(rt) == 1
              cname = rt[4, rt.length - 4]
              ci = find_class_idx(cname)
              if ci >= 0
                writers = @cls_attr_writers[ci].split(";")
                wk = 0
                while wk < writers.length
                  if writers[wk] == bname
                    iname = "@" + bname
                    args_id = @nd_arguments[nid]
                    if args_id >= 0
                      arg_ids = get_args(args_id)
                      if arg_ids.length > 0
                        at = infer_type(arg_ids[0])
                        if at != "int"
                          if at != "nil"
                            update_ivar_type(ci, iname, at)
                          end
                        end
                      end
                    end
                  end
                  wk = wk + 1
                end
              end
            end
          end
        end
      end
    end
    # Recurse
    if @nd_body[nid] >= 0
      scan_writer_calls(@nd_body[nid])
    end
    stmts = parse_id_list(@nd_stmts[nid])
    k = 0
    while k < stmts.length
      scan_writer_calls(stmts[k])
      k = k + 1
    end
    if @nd_expression[nid] >= 0
      scan_writer_calls(@nd_expression[nid])
    end
    if @nd_arguments[nid] >= 0
      scan_writer_calls(@nd_arguments[nid])
    end
    args = parse_id_list(@nd_args[nid])
    k = 0
    while k < args.length
      scan_writer_calls(args[k])
      k = k + 1
    end
    if @nd_block[nid] >= 0
      scan_writer_calls(@nd_block[nid])
    end
    if @nd_predicate[nid] >= 0
      scan_writer_calls(@nd_predicate[nid])
    end
    if @nd_subsequent[nid] >= 0
      scan_writer_calls(@nd_subsequent[nid])
    end
    if @nd_else_clause[nid] >= 0
      scan_writer_calls(@nd_else_clause[nid])
    end
  end

  def infer_all_returns
    # Pre-pass: infer class method param types from body usage
    infer_cls_meth_param_from_body
    # Pre-pass: scan for .new calls to infer constructor param types
    infer_constructor_types
    # Update ivar types from constructor params
    update_ivar_types_from_params

    # Top-level methods
    i = 0
    while i < @meth_names.length
      push_scope
      pnames = @meth_param_names[i].split(",")
      ptypes = @meth_param_types[i].split(",")
      j = 0
      while j < pnames.length
        pt = "int"
        if j < ptypes.length
          pt = ptypes[j]
        end
        declare_var(pnames[j], pt)
        j = j + 1
      end
      # Also declare locals for better return type inference
      if @meth_body_ids[i] >= 0
        lnames = []
        ltypes = []
        scan_locals(@meth_body_ids[i], lnames, ltypes, pnames)
        lk = 0
        while lk < lnames.length
          declare_var(lnames[lk], ltypes[lk])
          lk = lk + 1
        end
      end
      rt = infer_body_return(@meth_body_ids[i])
      @meth_return_types[i] = rt
      pop_scope
      i = i + 1
    end

    # Class methods
    i = 0
    while i < @cls_names.length
      @current_class_idx = i
      mnames = @cls_meth_names[i].split(";")
      all_params = @cls_meth_params[i].split("|")
      all_ptypes = @cls_meth_ptypes[i].split("|")
      bodies = @cls_meth_bodies[i].split(";")
      returns = @cls_meth_returns[i].split(";")

      j = 0
      while j < mnames.length
        push_scope
        pnames = []
        ptypes = []
        if j < all_params.length
          pnames = all_params[j].split(",")
        end
        if j < all_ptypes.length
          ptypes = all_ptypes[j].split(",")
        end

        # Infer param types for initialize
        if mnames[j] == "initialize"
          k = 0
          while k < pnames.length
            pt = infer_init_param_type(i, pnames[k])
            if k < ptypes.length
              ptypes[k] = pt
            end
            declare_var(pnames[k], pt)
            k = k + 1
          end
          # Update ptypes in class storage
          new_ptypes = join_sep(ptypes, ",")
          if j < all_ptypes.length
            all_ptypes[j] = new_ptypes
          end
          @cls_meth_ptypes[i] = join_sep(all_ptypes, "|")
        else
          k = 0
          while k < pnames.length
            pt = "int"
            if k < ptypes.length
              pt = ptypes[k]
            end
            declare_var(pnames[k], pt)
            k = k + 1
          end
        end

        bid = -1
        if j < bodies.length
          bid = bodies[j].to_i
        end
        rt = "int"
        if mnames[j] == "initialize"
          rt = "void"
        else
          if mnames[j] == "to_s"
            rt = "string"
          else
            rt = infer_body_return(bid)
          end
        end
        if j < returns.length
          returns[j] = rt
        end
        # Save incrementally so later methods can see updated return types
        @cls_meth_returns[i] = join_sep(returns, ";")
        pop_scope
        j = j + 1
      end

      # Class methods
      cmnames = @cls_cmeth_names[i].split(";")
      cm_bodies = @cls_cmeth_bodies[i].split(";")
      cm_returns = @cls_cmeth_returns[i].split(";")
      j = 0
      while j < cmnames.length
        push_scope
        bid = -1
        if j < cm_bodies.length
          bid = cm_bodies[j].to_i
        end
        rt = infer_body_return(bid)
        if j < cm_returns.length
          cm_returns[j] = rt
        end
        pop_scope
        j = j + 1
      end
      @cls_cmeth_returns[i] = join_sep(cm_returns, ";")
      @current_class_idx = -1
      i = i + 1
    end
  end

  def infer_init_param_type(ci, pname)
    # Check if param is assigned to an ivar in initialize
    mnames = @cls_meth_names[ci].split(";")
    bodies = @cls_meth_bodies[ci].split(";")
    j = 0
    while j < mnames.length
      if mnames[j] == "initialize"
        bid = -1
        if j < bodies.length
          bid = bodies[j].to_i
        end
        if bid >= 0
          stmts = get_stmts(bid)
          k = 0
          while k < stmts.length
            sid = stmts[k]
            if @nd_type[sid] == "InstanceVariableWriteNode"
              expr = @nd_expression[sid]
              if expr >= 0
                if @nd_type[expr] == "LocalVariableReadNode"
                  if @nd_name[expr] == pname
                    return cls_ivar_type(ci, @nd_name[sid])
                  end
                end
              end
            end
            # Also check super calls
            if @nd_type[sid] == "SuperNode"
              super_args = @nd_arguments[sid]
              if super_args >= 0
                sa_ids = get_args(super_args)
                sk = 0
                while sk < sa_ids.length
                  if @nd_type[sa_ids[sk]] == "LocalVariableReadNode"
                    if @nd_name[sa_ids[sk]] == pname
                      # This param is passed to parent's initialize at position sk
                      if @cls_parents[ci] != ""
                        parent_ci = find_class_idx(@cls_parents[ci])
                        if parent_ci >= 0
                          parent_init = cls_find_method_direct(parent_ci, "initialize")
                          if parent_init >= 0
                            parent_ptypes = @cls_meth_ptypes[parent_ci].split("|")
                            if parent_init < parent_ptypes.length
                              ppt = parent_ptypes[parent_init].split(",")
                              if sk < ppt.length
                                return ppt[sk]
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                  sk = sk + 1
                end
              end
            end
            k = k + 1
          end
        end
      end
      j = j + 1
    end
    "int"
  end

  def infer_body_return(body_id)
    if body_id < 0
      return "void"
    end
    stmts = get_stmts(body_id)
    if stmts.length == 0
      return "void"
    end
    # Check for explicit returns
    rt = scan_return_type_list(stmts)
    if rt != ""
      return rt
    end
    # Last expression
    infer_type(stmts[stmts.length - 1])
  end

  def scan_return_type_list(stmts)
    i = 0
    while i < stmts.length
      rt = scan_return_type(stmts[i])
      if rt != ""
        return rt
      end
      i = i + 1
    end
    ""
  end

  def scan_return_type(nid)
    if nid < 0
      return ""
    end
    if @nd_type[nid] == "ReturnNode"
      args_id = @nd_arguments[nid]
      if args_id >= 0
        arg_ids = get_args(args_id)
        if arg_ids.length > 0
          return infer_type(arg_ids[0])
        end
      end
      return "void"
    end
    if @nd_type[nid] == "IfNode"
      r1 = ""
      body = @nd_body[nid]
      if body >= 0
        stmts = get_stmts(body)
        r1 = scan_return_type_list(stmts)
      end
      sub = @nd_subsequent[nid]
      if sub >= 0
        r2 = scan_return_type(sub)
        if r2 != ""
          r1 = r2
        end
      end
      return r1
    end
    if @nd_type[nid] == "ElseNode"
      body = @nd_body[nid]
      if body >= 0
        stmts = get_stmts(body)
        return scan_return_type_list(stmts)
      end
    end
    if @nd_type[nid] == "WhileNode"
      body = @nd_body[nid]
      if body >= 0
        stmts = get_stmts(body)
        return scan_return_type_list(stmts)
      end
    end
    if @nd_type[nid] == "CaseMatchNode"
      conds = parse_id_list(@nd_conditions[nid])
      if conds.length > 0
        inid = conds[0]
        if @nd_type[inid] == "InNode"
          ibody = @nd_body[inid]
          if ibody >= 0
            is = get_stmts(ibody)
            rt = scan_return_type_list(is)
            if rt != ""
              return rt
            end
          end
        end
      end
    end
    ""
  end

  # ---- Feature detection ----
  def detect_features
    # Set up a temporary scope with main-level locals so feature detection
    # can infer types of local variables correctly
    push_scope
    stmts = get_body_stmts(@root_id)
    lnames = "".split(",")
    ltypes = "".split(",")
    empty_p = "".split(",")
    i = 0
    while i < stmts.length
      sid = stmts[i]
      if @nd_type[sid] != "DefNode"
        if @nd_type[sid] != "ClassNode"
          if @nd_type[sid] != "ConstantWriteNode"
            if @nd_type[sid] != "ModuleNode"
              scan_locals(sid, lnames, ltypes, empty_p)
            end
          end
        end
      end
      i = i + 1
    end
    k = 0
    while k < lnames.length
      declare_var(lnames[k], ltypes[k])
      k = k + 1
    end
    scan_features(@root_id)
    pop_scope
  end

  def scan_features(nid)
    if nid < 0
      return
    end
    t = @nd_type[nid]
    if t == "BeginNode"
      if @nd_rescue_clause[nid] >= 0
        @needs_setjmp = 1
      end
      if @nd_ensure_clause[nid] >= 0
        @needs_setjmp = 1
      end
    end
    if t == "InterpolatedXStringNode"
      @needs_file_io = 1
      @needs_string_helpers = 1
    end
    if t == "XStringNode"
      @needs_file_io = 1
    end
    if t == "ArrayNode"
      et = infer_array_elem_type(nid)
      if et == "str_array"
        @needs_str_array = 1
      else
        @needs_int_array = 1
      end
      @needs_gc = 1
    end
    if t == "HashNode"
      ht = infer_hash_val_type(nid)
      if ht == "str_str_hash"
        @needs_str_str_hash = 1
      else
        @needs_str_int_hash = 1
      end
      @needs_gc = 1
      @needs_str_array = 1
    end
    if t == "InterpolatedStringNode"
      @needs_string_helpers = 1
    end
    if t == "SymbolNode"
      @needs_string_helpers = 1
    end
    if t == "CallNode"
      mname = @nd_name[nid]
      if mname == "to_s"
        @needs_string_helpers = 1
      end
      if mname == "+"
        if @nd_receiver[nid] >= 0
          rt = infer_type(@nd_receiver[nid])
          if rt == "string"
            @needs_string_helpers = 1
          end
        end
      end
      if mname == "upcase"
        @needs_string_helpers = 1
      end
      if mname == "<<"
        if @nd_receiver[nid] >= 0
          rt = infer_type(@nd_receiver[nid])
          if rt == "string"
            @needs_string_helpers = 1
          end
        end
      end
      if mname == "+"
        if @nd_receiver[nid] >= 0
          rt = infer_type(@nd_receiver[nid])
          if rt == "string"
            @needs_string_helpers = 1
          end
        end
      end
      if mname == "downcase"
        @needs_string_helpers = 1
      end
      if mname == "strip"
        @needs_string_helpers = 1
      end
      if mname == "chomp"
        @needs_string_helpers = 1
      end
      if mname == "include?"
        @needs_string_helpers = 1
      end
      if mname == "start_with?"
        @needs_string_helpers = 1
      end
      if mname == "end_with?"
        @needs_string_helpers = 1
      end
      if mname == "split"
        @needs_string_helpers = 1
        @needs_str_array = 1
        @needs_gc = 1
      end
      if mname == "gsub"
        @needs_string_helpers = 1
      end
      if mname == "index"
        @needs_string_helpers = 1
      end
      if mname == "sub"
        @needs_string_helpers = 1
      end
      if mname == "[]"
        if @nd_receiver[nid] >= 0
          rt = infer_type(@nd_receiver[nid])
          if rt == "string"
            @needs_string_helpers = 1
          end
        end
      end
      if mname == "reverse"
        if @nd_receiver[nid] >= 0
          rt = infer_type(@nd_receiver[nid])
          if rt == "string"
            @needs_string_helpers = 1
          end
        end
      end
      if mname == "capitalize"
        @needs_string_helpers = 1
      end
      if mname == "count"
        @needs_string_helpers = 1
      end
      if mname == "*"
        if @nd_receiver[nid] >= 0
          rt = infer_type(@nd_receiver[nid])
          if rt == "string"
            @needs_string_helpers = 1
          end
        end
      end
      if mname == "new"
        if @nd_receiver[nid] >= 0
          if @nd_type[@nd_receiver[nid]] == "ConstantReadNode"
            @needs_gc = 1
            rn = @nd_name[@nd_receiver[nid]]
            if rn == "Array"
              @needs_int_array = 1
            end
            if rn == "Hash"
              @needs_str_int_hash = 1
            end
          end
        end
      end
      if mname == "to_a"
        if @nd_receiver[nid] >= 0
          rt = infer_type(@nd_receiver[nid])
          if rt == "range"
            @needs_int_array = 1
            @needs_gc = 1
          end
        end
      end
      if mname == "sort"
        @needs_int_array = 1
        @needs_gc = 1
      end
      if mname == "reduce"
        @needs_int_array = 1
        @needs_gc = 1
      end
      if mname == "inject"
        @needs_int_array = 1
        @needs_gc = 1
      end
      if mname == "reject"
        @needs_int_array = 1
        @needs_gc = 1
      end
      if mname == "raise"
        @needs_setjmp = 1
      end
      if mname == "catch"
        @needs_setjmp = 1
      end
      if mname == "throw"
        @needs_setjmp = 1
      end
      if mname == "system"
        @needs_file_io = 1
      end
      if @nd_receiver[nid] >= 0
        if @nd_type[@nd_receiver[nid]] == "ConstantReadNode"
          rn = @nd_name[@nd_receiver[nid]]
          if rn == "File"
            @needs_file_io = 1
            if mname == "join"
              @needs_string_helpers = 1
            end
            if mname == "basename"
              @needs_string_helpers = 1
            end
          end
        end
      end
      if mname == "keys"
        @needs_str_array = 1
        @needs_gc = 1
      end
      if mname == "each"
        if @nd_receiver[nid] >= 0
          rt = infer_type(@nd_receiver[nid])
          if rt == "str_int_hash"
            @needs_str_int_hash = 1
          end
          if rt == "str_str_hash"
            @needs_str_str_hash = 1
          end
        end
      end
    end
    # Recurse
    scan_features_children(nid)
  end

  def scan_features_children(nid)
    if @nd_body[nid] >= 0
      scan_features(@nd_body[nid])
    end
    stmts = parse_id_list(@nd_stmts[nid])
    k = 0
    while k < stmts.length
      scan_features(stmts[k])
      k = k + 1
    end
    if @nd_expression[nid] >= 0
      scan_features(@nd_expression[nid])
    end
    if @nd_predicate[nid] >= 0
      scan_features(@nd_predicate[nid])
    end
    if @nd_subsequent[nid] >= 0
      scan_features(@nd_subsequent[nid])
    end
    if @nd_else_clause[nid] >= 0
      scan_features(@nd_else_clause[nid])
    end
    if @nd_receiver[nid] >= 0
      scan_features(@nd_receiver[nid])
    end
    if @nd_arguments[nid] >= 0
      scan_features(@nd_arguments[nid])
    end
    args = parse_id_list(@nd_args[nid])
    k = 0
    while k < args.length
      scan_features(args[k])
      k = k + 1
    end
    conds = parse_id_list(@nd_conditions[nid])
    k = 0
    while k < conds.length
      scan_features(conds[k])
      k = k + 1
    end
    elems = parse_id_list(@nd_elements[nid])
    k = 0
    while k < elems.length
      scan_features(elems[k])
      k = k + 1
    end
    parts = parse_id_list(@nd_parts[nid])
    k = 0
    while k < parts.length
      scan_features(parts[k])
      k = k + 1
    end
    if @nd_left[nid] >= 0
      scan_features(@nd_left[nid])
    end
    if @nd_right[nid] >= 0
      scan_features(@nd_right[nid])
    end
    if @nd_block[nid] >= 0
      scan_features(@nd_block[nid])
    end
    if @nd_key[nid] >= 0
      scan_features(@nd_key[nid])
    end
    if @nd_collection[nid] >= 0
      scan_features(@nd_collection[nid])
    end
    if @nd_target[nid] >= 0
      scan_features(@nd_target[nid])
    end
    if @nd_parameters[nid] >= 0
      scan_features(@nd_parameters[nid])
    end
    reqs = parse_id_list(@nd_requireds[nid])
    k = 0
    while k < reqs.length
      scan_features(reqs[k])
      k = k + 1
    end
    opts = parse_id_list(@nd_optionals[nid])
    k = 0
    while k < opts.length
      scan_features(opts[k])
      k = k + 1
    end
  end

  # ---- Code generation ----
  def infer_main_call_types
    # Scan main-level code for function calls and infer param types from arguments
    stmts = get_body_stmts(@root_id)
    # First, figure out main local types
    push_scope
    lnames = "".split(",")
    ltypes = "".split(",")
    empty_p = "".split(",")
    i = 0
    while i < stmts.length
      sid = stmts[i]
      if @nd_type[sid] != "DefNode"
        if @nd_type[sid] != "ClassNode"
          if @nd_type[sid] != "ConstantWriteNode"
            scan_locals(sid, lnames, ltypes, empty_p)
          end
        end
      end
      i = i + 1
    end
    k = 0
    while k < lnames.length
      declare_var(lnames[k], ltypes[k])
      k = k + 1
    end
    # Now scan call sites to update param types
    scan_new_calls(@root_id)
    pop_scope
  end

  def detect_poly_params
    # Scan all call sites to detect functions called with different param types
    stmts = get_body_stmts(@root_id)
    i = 0
    while i < stmts.length
      detect_poly_in_node(stmts[i])
      i = i + 1
    end
  end

  def detect_poly_in_node(nid)
    if nid < 0
      return
    end
    if @nd_type[nid] == "CallNode"
      mname = @nd_name[nid]
      if @nd_receiver[nid] < 0
        mi = find_method_idx(mname)
        if mi >= 0
          args_id = @nd_arguments[nid]
          if args_id >= 0
            arg_ids = get_args(args_id)
            ptypes = @meth_param_types[mi].split(",")
            k = 0
            while k < arg_ids.length
              at = infer_type(arg_ids[k])
              if k < ptypes.length
                ct = ptypes[k]
                # Skip rest/splat params (int_array) - they handle multiple args
                if ct == "int_array"
                  k = k + 1
                  next
                end
                if ct != at
                  if ct != "poly"
                    # Only mark as poly if both types are meaningful
                    # (not just default "int" vs actual type)
                    if ct == "int"
                      # First real type seen - update, don't mark poly
                      ptypes[k] = at
                    else
                      if at == "int"
                        # Check if arg is a literal int (genuine int value)
                        if k < arg_ids.length
                          if @nd_type[arg_ids[k]] == "IntegerNode"
                            ptypes[k] = "poly"
                            @needs_rb_value = 1
                          end
                        end
                        # otherwise arg is int variable, param already has a type - keep it
                      else
                        # Genuinely different types - mark poly
                        ptypes[k] = "poly"
                        @needs_rb_value = 1
                      end
                    end
                  end
                end
              end
              k = k + 1
            end
            @meth_param_types[mi] = join_sep(ptypes, ",")
          end
        end
      end
    end
    # Recurse
    if @nd_body[nid] >= 0
      detect_poly_in_node(@nd_body[nid])
    end
    stmts = parse_id_list(@nd_stmts[nid])
    k = 0
    while k < stmts.length
      detect_poly_in_node(stmts[k])
      k = k + 1
    end
    if @nd_expression[nid] >= 0
      detect_poly_in_node(@nd_expression[nid])
    end
    if @nd_arguments[nid] >= 0
      detect_poly_in_node(@nd_arguments[nid])
    end
    args = parse_id_list(@nd_args[nid])
    k = 0
    while k < args.length
      detect_poly_in_node(args[k])
      k = k + 1
    end
    if @nd_predicate[nid] >= 0
      detect_poly_in_node(@nd_predicate[nid])
    end
    if @nd_subsequent[nid] >= 0
      detect_poly_in_node(@nd_subsequent[nid])
    end
    if @nd_else_clause[nid] >= 0
      detect_poly_in_node(@nd_else_clause[nid])
    end
    if @nd_block[nid] >= 0
      detect_poly_in_node(@nd_block[nid])
    end
    conds = parse_id_list(@nd_conditions[nid])
    k = 0
    while k < conds.length
      detect_poly_in_node(conds[k])
      k = k + 1
    end
  end

  def detect_poly_locals
    # Detect local variables assigned different types in main scope
    stmts = get_body_stmts(@root_id)
    local_types = "".split(",")
    local_names = "".split(",")
    i = 0
    while i < stmts.length
      sid = stmts[i]
      if @nd_type[sid] != "DefNode"
        if @nd_type[sid] != "ClassNode"
          scan_poly_assigns(sid, local_names, local_types)
        end
      end
      i = i + 1
    end
  end

  def scan_poly_assigns(nid, names, types)
    if nid < 0
      return
    end
    if @nd_type[nid] == "LocalVariableWriteNode"
      lname = @nd_name[nid]
      at = infer_type(@nd_expression[nid])
      idx = -1
      k = 0
      while k < names.length
        if names[k] == lname
          idx = k
        end
        k = k + 1
      end
      if idx >= 0
        if types[idx] != at
          if types[idx] != "poly"
            types[idx] = "poly"
            @needs_rb_value = 1
          end
        end
      else
        names.push(lname)
        types.push(at)
      end
    end
    # Recurse
    if @nd_body[nid] >= 0
      scan_poly_assigns(@nd_body[nid], names, types)
    end
    stmts = parse_id_list(@nd_stmts[nid])
    k = 0
    while k < stmts.length
      scan_poly_assigns(stmts[k], names, types)
      k = k + 1
    end
    if @nd_expression[nid] >= 0
      scan_poly_assigns(@nd_expression[nid], names, types)
    end
    if @nd_subsequent[nid] >= 0
      scan_poly_assigns(@nd_subsequent[nid], names, types)
    end
    if @nd_else_clause[nid] >= 0
      scan_poly_assigns(@nd_else_clause[nid], names, types)
    end
  end

  def compile
    collect_all
    infer_main_call_types
    detect_poly_params
    detect_poly_locals
    # Re-infer return types after main call type fixes
    infer_all_returns
    # Update ivar types from writer calls (after return types are known)
    infer_ivar_types_from_writers
    # Re-infer again with updated ivar types
    infer_all_returns
    detect_features
    generate_code
  end

  def generate_code
    stmts = get_body_stmts(@root_id)

    emit_header
    if @needs_gc == 1
      emit_gc_runtime
    end
    if @needs_int_array == 1
      emit_int_array_runtime
    end
    if @needs_str_array == 1
      emit_str_array_runtime
    end
    if @needs_str_int_hash == 1
      emit_str_int_hash_runtime
    end
    if @needs_str_str_hash == 1
      emit_str_str_hash_runtime
    end
    if @needs_string_helpers == 1
      # String helpers need StrArray (for split), IntArray (for bytes), and GC
      if @needs_gc == 0
        @needs_gc = 1
        emit_gc_runtime
      end
      if @needs_int_array == 0
        @needs_int_array = 1
        emit_int_array_runtime
      end
      if @needs_str_array == 0
        @needs_str_array = 1
        emit_str_array_runtime
      end
      emit_string_helpers
    end
    if @needs_rb_value == 1
      if @needs_string_helpers == 0
        @needs_string_helpers = 1
        if @needs_gc == 0
          @needs_gc = 1
          emit_gc_runtime
        end
        if @needs_int_array == 0
          @needs_int_array = 1
          emit_int_array_runtime
        end
        if @needs_str_array == 0
          @needs_str_array = 1
          emit_str_array_runtime
        end
        emit_string_helpers
      end
      emit_rb_value_runtime
    end
    if @needs_setjmp == 1
      emit_setjmp_runtime
    end
    if @needs_file_io == 1
      emit_file_io_runtime
    end
    emit_class_structs
    emit_forward_decls
    emit_class_methods
    emit_toplevel_methods
    emit_main
  end

  def emit_header
    emit_raw("/* Generated by Spinel v2 AOT compiler */")
    emit_raw("#include <stdio.h>")
    emit_raw("#include <stdlib.h>")
    emit_raw("#include <string.h>")
    emit_raw("#include <math.h>")
    emit_raw("#include <stdbool.h>")
    emit_raw("#include <stdint.h>")
    emit_raw("#include <ctype.h>")
    emit_raw("#include <stdarg.h>")
    emit_raw("#include <time.h>")
    emit_raw("")
    emit_raw("typedef int64_t mrb_int;")
    emit_raw("typedef double mrb_float;")
    emit_raw("typedef bool mrb_bool;")
    emit_raw("#ifndef TRUE")
    emit_raw("#define TRUE true")
    emit_raw("#endif")
    emit_raw("#ifndef FALSE")
    emit_raw("#define FALSE false")
    emit_raw("#endif")
    emit_raw("")
    emit_raw("static inline mrb_int sp_idiv(mrb_int a, mrb_int b) {")
    emit_raw("  mrb_int q = a / b; mrb_int r = a % b;")
    emit_raw("  if ((r != 0) && ((r ^ b) < 0)) q--;")
    emit_raw("  return q;")
    emit_raw("}")
    emit_raw("static inline mrb_int sp_imod(mrb_int a, mrb_int b) {")
    emit_raw("  mrb_int r = a % b;")
    emit_raw("  if ((r != 0) && ((r ^ b) < 0)) r += b;")
    emit_raw("  return r;")
    emit_raw("}")
    emit_raw("")
    emit_raw("static mrb_int sp_gcd(mrb_int a,mrb_int b){if(a<0)a=-a;if(b<0)b=-b;while(b){mrb_int t=b;b=a%b;a=t;}return a;}")
    emit_raw("static mrb_int sp_clamp(mrb_int v,mrb_int lo,mrb_int hi){return v<lo?lo:v>hi?hi:v;}")
    emit_raw("static const char*sp_int_chr(mrb_int n){char*s=(char*)malloc(2);s[0]=(char)n;s[1]=0;return s;}")
    emit_raw("typedef struct{mrb_int first;mrb_int last;}sp_Range;")
    emit_raw("static sp_Range sp_range_new(mrb_int f,mrb_int l){sp_Range r;r.first=f;r.last=l;return r;}")
    emit_raw("static int sp_last_status = 0;")
    emit_raw("")
  end

  def emit_gc_runtime
    emit_raw("typedef struct sp_gc_hdr { struct sp_gc_hdr *next; void (*finalize)(void *); void (*scan)(void *); unsigned marked : 1; } sp_gc_hdr;")
    emit_raw("static sp_gc_hdr *sp_gc_heap = NULL; static size_t sp_gc_bytes = 0; static size_t sp_gc_threshold = 256*1024;")
    emit_raw("#define SP_GC_STACK_MAX 8192")
    emit_raw("static void **sp_gc_roots[SP_GC_STACK_MAX]; static int sp_gc_nroots = 0;")
    emit_raw("#define SP_GC_SAVE() int _gc_saved = sp_gc_nroots")
    emit_raw("#define SP_GC_ROOT(v) do{if(sp_gc_nroots<SP_GC_STACK_MAX)sp_gc_roots[sp_gc_nroots++]=(void**)&(v);}while(0)")
    emit_raw("#define SP_GC_RESTORE() sp_gc_nroots = _gc_saved")
    emit_raw("static void sp_gc_mark(void*obj){if(!obj)return;sp_gc_hdr*h=(sp_gc_hdr*)((char*)obj-sizeof(sp_gc_hdr));if(h->marked)return;h->marked=1;if(h->scan)h->scan(obj);}")
    emit_raw("static void sp_gc_collect(void){for(int i=0;i<sp_gc_nroots;i++){void*obj=*sp_gc_roots[i];if(obj)sp_gc_mark(obj);}sp_gc_hdr**pp=&sp_gc_heap;sp_gc_bytes=0;while(*pp){sp_gc_hdr*h=*pp;if(!h->marked){*pp=h->next;if(h->finalize)h->finalize((char*)h+sizeof(sp_gc_hdr));free(h);}else{h->marked=0;sp_gc_bytes+=sizeof(sp_gc_hdr);pp=&h->next;}}}")
    emit_raw("static void*sp_gc_alloc(size_t sz,void(*fin)(void*),void(*scn)(void*)){if(sp_gc_bytes>sp_gc_threshold){sp_gc_collect();if(sp_gc_bytes>sp_gc_threshold/2)sp_gc_threshold*=2;}sp_gc_hdr*h=(sp_gc_hdr*)calloc(1,sizeof(sp_gc_hdr)+sz);h->finalize=fin;h->scan=scn;h->next=sp_gc_heap;sp_gc_heap=h;sp_gc_bytes+=sizeof(sp_gc_hdr)+sz;return(char*)h+sizeof(sp_gc_hdr);}")
    emit_raw("")
  end

  def emit_int_array_runtime
    emit_raw("typedef struct{mrb_int*data;mrb_int start;mrb_int len;mrb_int cap;}sp_IntArray;")
    emit_raw("static void sp_IntArray_fin(void*p){free(((sp_IntArray*)p)->data);}")
    emit_raw("static sp_IntArray*sp_IntArray_new(void){sp_IntArray*a=(sp_IntArray*)sp_gc_alloc(sizeof(sp_IntArray),sp_IntArray_fin,NULL);a->cap=16;a->data=(mrb_int*)malloc(sizeof(mrb_int)*a->cap);a->start=0;a->len=0;return a;}")
    emit_raw("static sp_IntArray*sp_IntArray_from_range(mrb_int s,mrb_int e){sp_IntArray*a=sp_IntArray_new();mrb_int n=e-s+1;if(n<0)n=0;if(n>a->cap){a->cap=n;a->data=(mrb_int*)realloc(a->data,sizeof(mrb_int)*a->cap);}for(mrb_int i=0;i<n;i++)a->data[i]=s+i;a->len=n;return a;}")
    emit_raw("static sp_IntArray*sp_IntArray_dup(sp_IntArray*a){sp_IntArray*b=sp_IntArray_new();if(a->len>b->cap){b->cap=a->len;b->data=(mrb_int*)realloc(b->data,sizeof(mrb_int)*b->cap);}memcpy(b->data,a->data+a->start,sizeof(mrb_int)*a->len);b->len=a->len;return b;}")
    emit_raw("static void sp_IntArray_push(sp_IntArray*a,mrb_int v){mrb_int e=a->start+a->len;if(e>=a->cap){if(a->start>0){memmove(a->data,a->data+a->start,sizeof(mrb_int)*a->len);a->start=0;e=a->len;}if(e>=a->cap){a->cap=a->cap*2+1;a->data=(mrb_int*)realloc(a->data,sizeof(mrb_int)*a->cap);}}a->data[e]=v;a->len++;}")
    emit_raw("static mrb_int sp_IntArray_pop(sp_IntArray*a){return a->data[a->start+--a->len];}")
    emit_raw("static mrb_int sp_IntArray_length(sp_IntArray*a){return a->len;}")
    emit_raw("static mrb_bool sp_IntArray_empty(sp_IntArray*a){return a->len==0;}")
    emit_raw("static mrb_int sp_IntArray_get(sp_IntArray*a,mrb_int i){if(i<0)i+=a->len;return a->data[a->start+i];}")
    emit_raw("static void sp_IntArray_set(sp_IntArray*a,mrb_int i,mrb_int v){if(i<0)i+=a->len;while(a->start+i>=a->cap){a->cap=a->cap*2+1;a->data=(mrb_int*)realloc(a->data,sizeof(mrb_int)*a->cap);}while(i>=a->len){a->data[a->start+a->len]=0;a->len++;}a->data[a->start+i]=v;}")
    emit_raw("static void sp_IntArray_reverse_bang(sp_IntArray*a){for(mrb_int i=0,j=a->len-1;i<j;i++,j--){mrb_int t=a->data[a->start+i];a->data[a->start+i]=a->data[a->start+j];a->data[a->start+j]=t;}}")
    emit_raw("static int _sp_int_cmp(const void*a,const void*b){mrb_int va=*(const mrb_int*)a,vb=*(const mrb_int*)b;return(va>vb)-(va<vb);}")
    emit_raw("static sp_IntArray*sp_IntArray_sort(sp_IntArray*a){sp_IntArray*b=sp_IntArray_dup(a);qsort(b->data+b->start,b->len,sizeof(mrb_int),_sp_int_cmp);return b;}")
    emit_raw("static void sp_IntArray_sort_bang(sp_IntArray*a){qsort(a->data+a->start,a->len,sizeof(mrb_int),_sp_int_cmp);}")
    emit_raw("static mrb_int sp_IntArray_min(sp_IntArray*a){mrb_int m=a->data[a->start];for(mrb_int i=1;i<a->len;i++)if(a->data[a->start+i]<m)m=a->data[a->start+i];return m;}")
    emit_raw("static mrb_int sp_IntArray_max(sp_IntArray*a){mrb_int m=a->data[a->start];for(mrb_int i=1;i<a->len;i++)if(a->data[a->start+i]>m)m=a->data[a->start+i];return m;}")
    emit_raw("static mrb_int sp_IntArray_sum(sp_IntArray*a){mrb_int s=0;for(mrb_int i=0;i<a->len;i++)s+=a->data[a->start+i];return s;}")
    emit_raw("static mrb_bool sp_IntArray_include(sp_IntArray*a,mrb_int v){for(mrb_int i=0;i<a->len;i++)if(a->data[a->start+i]==v)return TRUE;return FALSE;}")
    emit_raw("static sp_IntArray*sp_IntArray_uniq(sp_IntArray*a){sp_IntArray*b=sp_IntArray_new();for(mrb_int i=0;i<a->len;i++){int found=0;for(mrb_int j=0;j<b->len;j++){if(b->data[b->start+j]==a->data[a->start+i]){found=1;break;}}if(!found)sp_IntArray_push(b,a->data[a->start+i]);}return b;}")
    emit_raw("static const char*sp_IntArray_join(sp_IntArray*a,const char*sep){size_t sl=strlen(sep),cap=256;char*buf=(char*)malloc(cap);size_t len=0;for(mrb_int i=0;i<a->len;i++){if(i>0){if(len+sl>=cap){cap*=2;buf=(char*)realloc(buf,cap);}memcpy(buf+len,sep,sl);len+=sl;}char tmp[32];int n=snprintf(tmp,32,\"%lld\",(long long)a->data[a->start+i]);if(len+n>=cap){cap*=2;buf=(char*)realloc(buf,cap);}memcpy(buf+len,tmp,n);len+=n;}buf[len]=0;return buf;}")
    emit_raw("")
  end

  def emit_str_array_runtime
    emit_raw("typedef struct{const char**data;mrb_int len;mrb_int cap;}sp_StrArray;")
    emit_raw("static void sp_StrArray_fin(void*p){free(((sp_StrArray*)p)->data);}")
    emit_raw("static sp_StrArray*sp_StrArray_new(void){sp_StrArray*a=(sp_StrArray*)sp_gc_alloc(sizeof(sp_StrArray),sp_StrArray_fin,NULL);a->cap=16;a->data=(const char**)malloc(sizeof(const char*)*a->cap);a->len=0;return a;}")
    emit_raw("static void sp_StrArray_push(sp_StrArray*a,const char*v){if(a->len>=a->cap){a->cap=a->cap*2+1;a->data=(const char**)realloc(a->data,sizeof(const char*)*a->cap);}a->data[a->len++]=v;}")
    emit_raw("static const char*sp_StrArray_pop(sp_StrArray*a){return a->data[--a->len];}")
    emit_raw("static mrb_int sp_StrArray_length(sp_StrArray*a){return a->len;}")
    emit_raw("static mrb_bool sp_StrArray_empty(sp_StrArray*a){return a->len==0;}")
    emit_raw("static const char*sp_StrArray_get(sp_StrArray*a,mrb_int i){if(i<0)i+=a->len;return a->data[i];}")
    emit_raw("static void sp_StrArray_set(sp_StrArray*a,mrb_int i,const char*v){if(i<0)i+=a->len;while(i>=a->len)sp_StrArray_push(a,\"\");a->data[i]=v;}")
    emit_raw("static const char*sp_StrArray_join(sp_StrArray*a,const char*sep){size_t sl=strlen(sep),cap=256;char*buf=(char*)malloc(cap);size_t len=0;for(mrb_int i=0;i<a->len;i++){if(i>0){if(len+sl>=cap){cap*=2;buf=(char*)realloc(buf,cap);}memcpy(buf+len,sep,sl);len+=sl;}size_t el=strlen(a->data[i]);if(len+el>=cap){cap=(len+el)*2+1;buf=(char*)realloc(buf,cap);}memcpy(buf+len,a->data[i],el);len+=el;}buf[len]=0;return buf;}")
    emit_raw("static mrb_bool sp_StrArray_include(sp_StrArray*a,const char*v){for(mrb_int i=0;i<a->len;i++)if(strcmp(a->data[i],v)==0)return TRUE;return FALSE;}")
    emit_raw("")
  end

  def emit_str_int_hash_runtime
    emit_raw("typedef struct{const char**keys;mrb_int*vals;mrb_int len;mrb_int cap;}sp_StrIntHash;")
    emit_raw("static void sp_StrIntHash_fin(void*p){sp_StrIntHash*h=(sp_StrIntHash*)p;free(h->keys);free(h->vals);}")
    emit_raw("static sp_StrIntHash*sp_StrIntHash_new(void){sp_StrIntHash*h=(sp_StrIntHash*)sp_gc_alloc(sizeof(sp_StrIntHash),sp_StrIntHash_fin,NULL);h->cap=16;h->keys=(const char**)malloc(sizeof(const char*)*h->cap);h->vals=(mrb_int*)malloc(sizeof(mrb_int)*h->cap);h->len=0;return h;}")
    emit_raw("static mrb_int sp_StrIntHash_get(sp_StrIntHash*h,const char*k){for(mrb_int i=0;i<h->len;i++)if(strcmp(h->keys[i],k)==0)return h->vals[i];return 0;}")
    emit_raw("static void sp_StrIntHash_set(sp_StrIntHash*h,const char*k,mrb_int v){for(mrb_int i=0;i<h->len;i++){if(strcmp(h->keys[i],k)==0){h->vals[i]=v;return;}}if(h->len>=h->cap){h->cap*=2;h->keys=(const char**)realloc(h->keys,sizeof(const char*)*h->cap);h->vals=(mrb_int*)realloc(h->vals,sizeof(mrb_int)*h->cap);}h->keys[h->len]=k;h->vals[h->len]=v;h->len++;}")
    emit_raw("static mrb_bool sp_StrIntHash_has_key(sp_StrIntHash*h,const char*k){for(mrb_int i=0;i<h->len;i++)if(strcmp(h->keys[i],k)==0)return TRUE;return FALSE;}")
    emit_raw("static mrb_int sp_StrIntHash_length(sp_StrIntHash*h){return h->len;}")
    emit_raw("static void sp_StrIntHash_delete(sp_StrIntHash*h,const char*k){for(mrb_int i=0;i<h->len;i++){if(strcmp(h->keys[i],k)==0){for(mrb_int j=i;j<h->len-1;j++){h->keys[j]=h->keys[j+1];h->vals[j]=h->vals[j+1];}h->len--;return;}}}")
    emit_raw("static sp_StrArray*sp_StrIntHash_keys(sp_StrIntHash*h){sp_StrArray*a=sp_StrArray_new();for(mrb_int i=0;i<h->len;i++)sp_StrArray_push(a,h->keys[i]);return a;}")
    emit_raw("")
  end

  def emit_str_str_hash_runtime
    emit_raw("typedef struct{const char**keys;const char**vals;mrb_int len;mrb_int cap;}sp_StrStrHash;")
    emit_raw("static void sp_StrStrHash_fin(void*p){sp_StrStrHash*h=(sp_StrStrHash*)p;free(h->keys);free(h->vals);}")
    emit_raw("static sp_StrStrHash*sp_StrStrHash_new(void){sp_StrStrHash*h=(sp_StrStrHash*)sp_gc_alloc(sizeof(sp_StrStrHash),sp_StrStrHash_fin,NULL);h->cap=16;h->keys=(const char**)malloc(sizeof(const char*)*h->cap);h->vals=(const char**)malloc(sizeof(const char*)*h->cap);h->len=0;return h;}")
    emit_raw("static const char*sp_StrStrHash_get(sp_StrStrHash*h,const char*k){for(mrb_int i=0;i<h->len;i++)if(strcmp(h->keys[i],k)==0)return h->vals[i];return\"\";}")
    emit_raw("static void sp_StrStrHash_set(sp_StrStrHash*h,const char*k,const char*v){for(mrb_int i=0;i<h->len;i++){if(strcmp(h->keys[i],k)==0){h->vals[i]=v;return;}}if(h->len>=h->cap){h->cap*=2;h->keys=(const char**)realloc(h->keys,sizeof(const char*)*h->cap);h->vals=(const char**)realloc(h->vals,sizeof(const char*)*h->cap);}h->keys[h->len]=k;h->vals[h->len]=v;h->len++;}")
    emit_raw("static mrb_bool sp_StrStrHash_has_key(sp_StrStrHash*h,const char*k){for(mrb_int i=0;i<h->len;i++)if(strcmp(h->keys[i],k)==0)return TRUE;return FALSE;}")
    emit_raw("static mrb_int sp_StrStrHash_length(sp_StrStrHash*h){return h->len;}")
    emit_raw("static void sp_StrStrHash_delete(sp_StrStrHash*h,const char*k){for(mrb_int i=0;i<h->len;i++){if(strcmp(h->keys[i],k)==0){for(mrb_int j=i;j<h->len-1;j++){h->keys[j]=h->keys[j+1];h->vals[j]=h->vals[j+1];}h->len--;return;}}}")
    emit_raw("static sp_StrArray*sp_StrStrHash_keys(sp_StrStrHash*h){sp_StrArray*a=sp_StrArray_new();for(mrb_int i=0;i<h->len;i++)sp_StrArray_push(a,h->keys[i]);return a;}")
    emit_raw("")
  end

  def emit_string_helpers
    emit_raw("static const char*sp_str_concat(const char*a,const char*b){size_t la=strlen(a),lb=strlen(b);char*r=(char*)malloc(la+lb+1);memcpy(r,a,la);memcpy(r+la,b,lb+1);return r;}")
    emit_raw("static const char*sp_int_to_s(mrb_int n){char*b=(char*)malloc(32);snprintf(b,32,\"%lld\",(long long)n);return b;}")
    emit_raw("static const char*sp_float_to_s(mrb_float f){char*b=(char*)malloc(64);snprintf(b,64,\"%g\",f);return b;}")
    emit_raw("static const char*sp_str_upcase(const char*s){size_t l=strlen(s);char*r=(char*)malloc(l+1);for(size_t i=0;i<=l;i++)r[i]=toupper((unsigned char)s[i]);return r;}")
    emit_raw("static const char*sp_str_downcase(const char*s){size_t l=strlen(s);char*r=(char*)malloc(l+1);for(size_t i=0;i<=l;i++)r[i]=tolower((unsigned char)s[i]);return r;}")
    emit_raw("static const char*sp_str_strip(const char*s){while(*s&&isspace((unsigned char)*s))s++;size_t l=strlen(s);while(l>0&&isspace((unsigned char)s[l-1]))l--;char*r=(char*)malloc(l+1);memcpy(r,s,l);r[l]=0;return r;}")
    emit_raw("static const char*sp_str_chomp(const char*s){size_t l=strlen(s);while(l>0&&(s[l-1]=='\\n'||s[l-1]=='\\r'))l--;char*r=(char*)malloc(l+1);memcpy(r,s,l);r[l]=0;return r;}")
    emit_raw("static mrb_bool sp_str_include(const char*s,const char*sub){return strstr(s,sub)!=NULL;}")
    emit_raw("static mrb_bool sp_str_start_with(const char*s,const char*p){return strncmp(s,p,strlen(p))==0;}")
    emit_raw("static mrb_bool sp_str_end_with(const char*s,const char*suf){size_t ls=strlen(s),lsuf=strlen(suf);if(lsuf>ls)return FALSE;return strcmp(s+ls-lsuf,suf)==0;}")
    emit_raw("static sp_StrArray*sp_str_split(const char*s,const char*sep){sp_StrArray*a=sp_StrArray_new();size_t sl=strlen(sep);if(sl==0){for(size_t i=0;s[i];i++){char*c=(char*)malloc(2);c[0]=s[i];c[1]=0;sp_StrArray_push(a,c);}return a;}const char*p=s;while(1){const char*f=strstr(p,sep);if(!f){char*r=(char*)malloc(strlen(p)+1);strcpy(r,p);sp_StrArray_push(a,r);break;}size_t n=f-p;char*r=(char*)malloc(n+1);memcpy(r,p,n);r[n]=0;sp_StrArray_push(a,r);p=f+sl;}return a;}")
    emit_raw("static const char*sp_str_gsub(const char*s,const char*pat,const char*rep){size_t pl=strlen(pat),rl=strlen(rep),sl=strlen(s);if(pl==0)return s;size_t cap=sl*2+1;char*out=(char*)malloc(cap);size_t ol=0;const char*p=s;while(*p){const char*f=strstr(p,pat);if(!f){size_t n=strlen(p);if(ol+n>=cap){cap=(ol+n)*2+1;out=(char*)realloc(out,cap);}memcpy(out+ol,p,n);ol+=n;break;}size_t n=f-p;if(ol+n+rl>=cap){cap=(ol+n+rl)*2+1;out=(char*)realloc(out,cap);}memcpy(out+ol,p,n);ol+=n;memcpy(out+ol,rep,rl);ol+=rl;p=f+pl;}out[ol]=0;return out;}")
    emit_raw("static mrb_int sp_str_index(const char*s,const char*sub){const char*f=strstr(s,sub);if(!f)return -1;return(mrb_int)(f-s);}")
    emit_raw("static const char*sp_str_sub_range(const char*s,mrb_int start,mrb_int len){mrb_int sl=(mrb_int)strlen(s);if(start<0)start+=sl;if(start<0)start=0;if(start>=sl)return\"\";if(len<0)len=0;if(start+len>sl)len=sl-start;char*r=(char*)malloc(len+1);memcpy(r,s+start,len);r[len]=0;return r;}")
    emit_raw("static const char*sp_sprintf(const char*fmt,...){char*b=(char*)malloc(4096);va_list ap;va_start(ap,fmt);vsnprintf(b,4096,fmt,ap);va_end(ap);return b;}")
    emit_raw("static const char*sp_str_reverse(const char*s){size_t l=strlen(s);char*r=(char*)malloc(l+1);for(size_t i=0;i<l;i++)r[i]=s[l-1-i];r[l]=0;return r;}")
    emit_raw("static const char*sp_str_sub(const char*s,const char*pat,const char*rep){const char*f=strstr(s,pat);if(!f)return s;size_t pl=strlen(pat),rl=strlen(rep),sl=strlen(s);char*r=(char*)malloc(sl-pl+rl+1);size_t n=f-s;memcpy(r,s,n);memcpy(r+n,rep,rl);memcpy(r+n+rl,f+pl,sl-n-pl+1);return r;}")
    emit_raw("static const char*sp_str_capitalize(const char*s){size_t l=strlen(s);char*r=(char*)malloc(l+1);for(size_t i=0;i<=l;i++)r[i]=tolower((unsigned char)s[i]);if(l>0)r[0]=toupper((unsigned char)r[0]);return r;}")
    emit_raw("static mrb_int sp_str_count(const char*s,const char*chars){mrb_int c=0;for(size_t i=0;s[i];i++){for(size_t j=0;chars[j];j++){if(s[i]==chars[j]){c++;break;}}}return c;}")
    emit_raw("static const char*sp_str_repeat(const char*s,mrb_int n){if(n<=0)return\"\";size_t l=strlen(s);char*r=(char*)malloc(l*n+1);for(mrb_int i=0;i<n;i++)memcpy(r+l*i,s,l);r[l*n]=0;return r;}")
    emit_raw("static sp_IntArray*sp_str_bytes(const char*s){sp_IntArray*a=sp_IntArray_new();for(size_t i=0;s[i];i++)sp_IntArray_push(a,(mrb_int)(unsigned char)s[i]);return a;}")
    emit_raw("static const char*sp_str_tr(const char*s,const char*from,const char*to){size_t l=strlen(s),fl=strlen(from),tl=strlen(to);char*r=(char*)malloc(l+1);for(size_t i=0;i<l;i++){r[i]=s[i];for(size_t j=0;j<fl;j++){if(s[i]==from[j]){if(j<tl)r[i]=to[j];else if(tl>0)r[i]=to[tl-1];break;}}}r[l]=0;return r;}")
    emit_raw("static const char*sp_str_delete(const char*s,const char*chars){size_t l=strlen(s);char*r=(char*)malloc(l+1);size_t n=0;for(size_t i=0;i<l;i++){int found=0;for(size_t j=0;chars[j];j++){if(s[i]==chars[j]){found=1;break;}}if(!found)r[n++]=s[i];}r[n]=0;return r;}")
    emit_raw("static const char*sp_str_squeeze(const char*s){size_t l=strlen(s);char*r=(char*)malloc(l+1);size_t n=0;for(size_t i=0;i<l;i++){if(i==0||s[i]!=s[i-1])r[n++]=s[i];}r[n]=0;return r;}")
    emit_raw("static const char*sp_str_ljust(const char*s,mrb_int w){size_t l=strlen(s);if((mrb_int)l>=w)return s;char*r=(char*)malloc(w+1);memcpy(r,s,l);memset(r+l,' ',w-l);r[w]=0;return r;}")
    emit_raw("static const char*sp_str_rjust(const char*s,mrb_int w){size_t l=strlen(s);if((mrb_int)l>=w)return s;char*r=(char*)malloc(w+1);memset(r,' ',w-l);memcpy(r+w-l,s,l+1);return r;}")
    emit_raw("static const char*sp_str_center(const char*s,mrb_int w){size_t l=strlen(s);if((mrb_int)l>=w)return s;mrb_int pad=w-l;mrb_int left=pad/2;mrb_int right=pad-left;char*r=(char*)malloc(w+1);memset(r,' ',left);memcpy(r+left,s,l);memset(r+left+l,' ',right);r[w]=0;return r;}")
    emit_raw("static const char*sp_str_ljust2(const char*s,mrb_int w,const char*pad){size_t l=strlen(s);if((mrb_int)l>=w)return s;char*r=(char*)malloc(w+1);memcpy(r,s,l);char pc=pad[0];for(mrb_int i=l;i<w;i++)r[i]=pc;r[w]=0;return r;}")
    emit_raw("static const char*sp_str_rjust2(const char*s,mrb_int w,const char*pad){size_t l=strlen(s);if((mrb_int)l>=w)return s;char*r=(char*)malloc(w+1);char pc=pad[0];for(mrb_int i=0;i<w-(mrb_int)l;i++)r[i]=pc;memcpy(r+w-l,s,l+1);return r;}")
    emit_raw("static const char*sp_str_lstrip(const char*s){while(*s&&isspace((unsigned char)*s))s++;char*r=(char*)malloc(strlen(s)+1);strcpy(r,s);return r;}")
    emit_raw("static const char*sp_str_rstrip(const char*s){size_t l=strlen(s);while(l>0&&isspace((unsigned char)s[l-1]))l--;char*r=(char*)malloc(l+1);memcpy(r,s,l);r[l]=0;return r;}")
    emit_raw("static const char*sp_str_dup(const char*s){char*r=(char*)malloc(strlen(s)+1);strcpy(r,s);return r;}")
    emit_raw("")
  end

  def emit_rb_value_runtime
    emit_raw("/* NaN-boxed polymorphic value */")
    emit_raw("typedef uint64_t sp_RbValue;")
    emit_raw("#define SP_TAG_INT  0")
    emit_raw("#define SP_TAG_STR  1")
    emit_raw("#define SP_TAG_FLT  2")
    emit_raw("#define SP_TAG_BOOL 3")
    emit_raw("#define SP_TAG_NIL  4")
    emit_raw("#define SP_TAG_OBJ  5")
    emit_raw("typedef struct { int tag; union { mrb_int i; const char *s; mrb_float f; mrb_bool b; void *p; int cls_id; } v; } sp_RbVal;")
    emit_raw("static sp_RbVal sp_box_int(mrb_int v) { sp_RbVal r; r.tag = SP_TAG_INT; r.v.i = v; return r; }")
    emit_raw("static sp_RbVal sp_box_str(const char *v) { sp_RbVal r; r.tag = SP_TAG_STR; r.v.s = v; return r; }")
    emit_raw("static sp_RbVal sp_box_float(mrb_float v) { sp_RbVal r; r.tag = SP_TAG_FLT; r.v.f = v; return r; }")
    emit_raw("static sp_RbVal sp_box_bool(mrb_bool v) { sp_RbVal r; r.tag = SP_TAG_BOOL; r.v.b = v; return r; }")
    emit_raw("static sp_RbVal sp_box_nil(void) { sp_RbVal r; r.tag = SP_TAG_NIL; r.v.i = 0; return r; }")
    emit_raw("static sp_RbVal sp_box_obj(void *p, int cls_id) { sp_RbVal r; r.tag = SP_TAG_OBJ; r.v.p = p; r.v.cls_id = cls_id; return r; }")
    emit_raw("static void sp_poly_puts(sp_RbVal v) {")
    emit_raw("  switch (v.tag) {")
    emit_raw("    case SP_TAG_INT: printf(\"%lld\\n\", (long long)v.v.i); break;")
    emit_raw("    case SP_TAG_STR: if (v.v.s) { fputs(v.v.s, stdout); if (!*v.v.s || v.v.s[strlen(v.v.s)-1] != '\\n') putchar('\\n'); } else putchar('\\n'); break;")
    emit_raw("    case SP_TAG_FLT: { char _fb[64]; snprintf(_fb,64,\"%g\",v.v.f); if(!strchr(_fb,'.')&&!strchr(_fb,'e')&&!strchr(_fb,'i')&&!strchr(_fb,'n')){strcat(_fb,\".0\");} printf(\"%s\\n\",_fb); break; }")
    emit_raw("    case SP_TAG_BOOL: puts(v.v.b ? \"true\" : \"false\"); break;")
    emit_raw("    case SP_TAG_NIL: putchar('\\n'); break;")
    emit_raw("    default: printf(\"%lld\\n\", (long long)v.v.i); break;")
    emit_raw("  }")
    emit_raw("}")
    emit_raw("static mrb_bool sp_poly_nil_p(sp_RbVal v) { return v.tag == SP_TAG_NIL; }")
    emit_raw("static const char *sp_poly_to_s(sp_RbVal v) { switch (v.tag) { case SP_TAG_INT: { char *b = (char*)malloc(32); snprintf(b, 32, \"%lld\", (long long)v.v.i); return b; } case SP_TAG_STR: return v.v.s ? v.v.s : \"\"; case SP_TAG_FLT: { char *b = (char*)malloc(64); snprintf(b, 64, \"%g\", v.v.f); return b; } case SP_TAG_BOOL: return v.v.b ? \"true\" : \"false\"; case SP_TAG_NIL: return \"\"; default: return \"\"; } }")
    emit_raw("static sp_RbVal sp_poly_add(sp_RbVal a, sp_RbVal b) { if (a.tag == SP_TAG_INT && b.tag == SP_TAG_INT) return sp_box_int(a.v.i + b.v.i); if (a.tag == SP_TAG_FLT && b.tag == SP_TAG_FLT) return sp_box_float(a.v.f + b.v.f); if (a.tag == SP_TAG_INT && b.tag == SP_TAG_FLT) return sp_box_float((mrb_float)a.v.i + b.v.f); if (a.tag == SP_TAG_FLT && b.tag == SP_TAG_INT) return sp_box_float(a.v.f + (mrb_float)b.v.i); if (a.tag == SP_TAG_STR && b.tag == SP_TAG_STR) return sp_box_str(sp_str_concat(a.v.s, b.v.s)); return sp_box_int(0); }")
    emit_raw("static sp_RbVal sp_poly_sub(sp_RbVal a, sp_RbVal b) { if (a.tag == SP_TAG_INT && b.tag == SP_TAG_INT) return sp_box_int(a.v.i - b.v.i); if (a.tag == SP_TAG_FLT && b.tag == SP_TAG_FLT) return sp_box_float(a.v.f - b.v.f); return sp_box_int(0); }")
    emit_raw("static sp_RbVal sp_poly_mul(sp_RbVal a, sp_RbVal b) { if (a.tag == SP_TAG_INT && b.tag == SP_TAG_INT) return sp_box_int(a.v.i * b.v.i); if (a.tag == SP_TAG_FLT && b.tag == SP_TAG_FLT) return sp_box_float(a.v.f * b.v.f); if (a.tag == SP_TAG_INT && b.tag == SP_TAG_FLT) return sp_box_float((mrb_float)a.v.i * b.v.f); if (a.tag == SP_TAG_FLT && b.tag == SP_TAG_INT) return sp_box_float(a.v.f * (mrb_float)b.v.i); return sp_box_int(0); }")
    emit_raw("static mrb_bool sp_poly_gt(sp_RbVal a, sp_RbVal b) { if (a.tag == SP_TAG_INT && b.tag == SP_TAG_INT) return a.v.i > b.v.i; if (a.tag == SP_TAG_FLT && b.tag == SP_TAG_FLT) return a.v.f > b.v.f; return FALSE; }")
    emit_raw("")
  end

  def emit_setjmp_runtime
    emit_raw("#include <setjmp.h>")
    emit_raw("#define SP_EXC_STACK_MAX 64")
    emit_raw("static jmp_buf sp_exc_stack[SP_EXC_STACK_MAX];")
    emit_raw("static const char *sp_exc_msg[SP_EXC_STACK_MAX];")
    emit_raw("static volatile int sp_exc_top = 0;")
    emit_raw("static const char *sp_exc_cls[SP_EXC_STACK_MAX];")
    emit_raw("static volatile const char *sp_last_exc_cls = \"\";")
    emit_raw("static void sp_raise_cls(const char *cls, const char *msg) { if (sp_exc_top > 0) { sp_exc_msg[sp_exc_top-1] = msg; sp_exc_cls[sp_exc_top-1] = cls; sp_last_exc_cls = cls; longjmp(sp_exc_stack[sp_exc_top-1], 1); } fprintf(stderr, \"unhandled exception: %s\\n\", msg); exit(1); }")
    emit_raw("static void sp_raise(const char *msg) { sp_raise_cls(\"RuntimeError\", msg); }")
    emit_raw("static mrb_bool sp_exc_is_a(const char *cls, const char *target) { return strcmp(cls, target) == 0; }")
    emit_raw("")
    # catch/throw support
    emit_raw("#define SP_CATCH_STACK_MAX 64")
    emit_raw("static jmp_buf sp_catch_stack[SP_CATCH_STACK_MAX];")
    emit_raw("static const char *sp_catch_tag[SP_CATCH_STACK_MAX];")
    emit_raw("static mrb_int sp_catch_val[SP_CATCH_STACK_MAX];")
    emit_raw("static volatile int sp_catch_top = 0;")
    emit_raw("static void sp_throw(const char *tag, mrb_int val) { int i = sp_catch_top - 1; while (i >= 0) { if (strcmp(sp_catch_tag[i], tag) == 0) { sp_catch_val[i] = val; sp_catch_top = i + 1; longjmp(sp_catch_stack[i], 1); } i--; } fprintf(stderr, \"uncaught throw: %s\\n\", tag); exit(1); }")
    emit_raw("")
  end

  def emit_file_io_runtime
    emit_raw("static const char *sp_file_read(const char *path) { FILE *f = fopen(path, \"rb\"); if (!f) return \"\"; fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET); char *buf = (char *)malloc(sz + 1); if (sz > 0) fread(buf, 1, sz, f); buf[sz] = 0; fclose(f); return buf; }")
    emit_raw("static void sp_file_write(const char *path, const char *data) { FILE *f = fopen(path, \"w\"); if (f) { fputs(data, f); fclose(f); } }")
    emit_raw("static mrb_bool sp_file_exist(const char *path) { FILE *f = fopen(path, \"r\"); if (f) { fclose(f); return TRUE; } return FALSE; }")
    emit_raw("static void sp_file_delete(const char *path) { remove(path); }")
    emit_raw("static const char *sp_backtick(const char *cmd) { FILE *p = popen(cmd, \"r\"); if (!p) return \"\"; char *buf = (char *)malloc(4096); size_t n = fread(buf, 1, 4095, p); buf[n] = 0; pclose(p); return buf; }")
    emit_raw("static const char *sp_file_basename(const char *path) { const char *s = strrchr(path, '/'); if (s) return s + 1; return path; }")
    emit_raw("")
  end

  # ---- Struct emission ----
  def emit_class_structs
    # Forward declare typedefs
    i = 0
    while i < @cls_names.length
      emit_raw("typedef struct sp_" + @cls_names[i] + "_s sp_" + @cls_names[i] + ";")
      i = i + 1
    end
    if @cls_names.length > 0
      emit_raw("")
    end
    # Struct definitions
    i = 0
    while i < @cls_names.length
      emit_raw("struct sp_" + @cls_names[i] + "_s {")
      emit_class_fields(i)
      emit_raw("};")
      emit_raw("")
      i = i + 1
    end
  end

  def emit_class_fields(ci)
    # Parent fields first
    if @cls_parents[ci] != ""
      pi = find_class_idx(@cls_parents[ci])
      if pi >= 0
        emit_parent_fields(pi)
      end
    end
    # Own fields (skip those inherited from parent)
    names = @cls_ivar_names[ci].split(";")
    types = @cls_ivar_types[ci].split(";")
    j = 0
    while j < names.length
      iname = names[j]
      itype = "int"
      if j < types.length
        itype = types[j]
      end
      # Skip if in parent chain
      if @cls_parents[ci] != ""
        pi = find_class_idx(@cls_parents[ci])
        if pi >= 0
          if ivar_in_chain(pi, iname) == 1
            j = j + 1
            next
          end
        end
      end
      fname = sanitize_ivar(iname)
      emit_raw("  " + c_type(itype) + " " + fname + ";")
      j = j + 1
    end
  end

  def emit_parent_fields(ci)
    if @cls_parents[ci] != ""
      pi = find_class_idx(@cls_parents[ci])
      if pi >= 0
        emit_parent_fields(pi)
      end
    end
    names = @cls_ivar_names[ci].split(";")
    types = @cls_ivar_types[ci].split(";")
    j = 0
    while j < names.length
      iname = names[j]
      itype = "int"
      if j < types.length
        itype = types[j]
      end
      if @cls_parents[ci] != ""
        pi = find_class_idx(@cls_parents[ci])
        if pi >= 0
          if ivar_in_chain(pi, iname) == 1
            j = j + 1
            next
          end
        end
      end
      fname = sanitize_ivar(iname)
      emit_raw("  " + c_type(itype) + " " + fname + ";")
      j = j + 1
    end
  end

  def ivar_in_chain(ci, iname)
    names = @cls_ivar_names[ci].split(";")
    k = 0
    while k < names.length
      if names[k] == iname
        return 1
      end
      k = k + 1
    end
    if @cls_parents[ci] != ""
      pi = find_class_idx(@cls_parents[ci])
      if pi >= 0
        return ivar_in_chain(pi, iname)
      end
    end
    0
  end

  # ---- Forward declarations ----
  def emit_forward_decls
    # Emit block helper functions accumulated during collection
    if @block_funcs != ""
      emit_raw(@block_funcs)
    end
    # Top-level methods
    i = 0
    while i < @meth_names.length
      yp = ""
      if @meth_has_yield[i] == 1
        yp = yield_params_suffix(i)
      end
      emit_raw("static " + c_type(@meth_return_types[i]) + " sp_" + sanitize_name(@meth_names[i]) + "(" + method_params_decl(i) + yp + ");")
      i = i + 1
    end
    # Class methods
    i = 0
    while i < @cls_names.length
      cname = @cls_names[i]
      # Constructor
      init_idx = cls_find_method_direct(i, "initialize")
      emit_raw("static sp_" + cname + " *sp_" + cname + "_new(" + constructor_params_decl(i) + ");")
      if init_idx >= 0
        emit_raw("static void sp_" + cname + "_initialize(sp_" + cname + " *self" + init_params_decl(i) + ");")
      end
      # Instance methods
      mnames = @cls_meth_names[i].split(";")
      returns = @cls_meth_returns[i].split(";")
      all_params = @cls_meth_params[i].split("|")
      all_ptypes = @cls_meth_ptypes[i].split("|")
      j = 0
      while j < mnames.length
        if mnames[j] != "initialize"
          rt = "int"
          if j < returns.length
            rt = returns[j]
          end
          yp = ""
          if cls_method_has_yield(i, j) == 1
            yp = yield_params_suffix_cls(i, j)
          end
          emit_raw("static " + c_type(rt) + " sp_" + cname + "_" + sanitize_name(mnames[j]) + "(sp_" + cname + " *self" + method_with_self_params(j, all_params, all_ptypes) + yp + ");")
        end
        j = j + 1
      end
      # Class methods
      cmnames = @cls_cmeth_names[i].split(";")
      cm_returns = @cls_cmeth_returns[i].split(";")
      cm_params = @cls_cmeth_params[i].split("|")
      cm_ptypes = @cls_cmeth_ptypes[i].split("|")
      j = 0
      while j < cmnames.length
        rt = "int"
        if j < cm_returns.length
          rt = cm_returns[j]
        end
        emit_raw("static " + c_type(rt) + " sp_" + cname + "_cls_" + sanitize_name(cmnames[j]) + "(" + cls_method_params_decl(j, cm_params, cm_ptypes) + ");")
        j = j + 1
      end
      i = i + 1
    end
    emit_raw("")
  end

  def yield_params_suffix(mi)
    pnames = @meth_param_names[mi].split(",")
    if pnames.length == 0
      return "void (*_block)(mrb_int, void*), void *_benv"
    end
    return ", void (*_block)(mrb_int, void*), void *_benv"
  end

  def yield_params_suffix_cls(ci, midx)
    # For class instance methods (always have self first)
    return ", void (*_block)(mrb_int, void*), void *_benv"
  end

  def cls_method_has_yield(ci, midx)
    ystr = @cls_meth_has_yield[ci].split(";")
    if midx < ystr.length
      if ystr[midx] == "1"
        return 1
      end
    end
    0
  end

  def cls_find_method_direct(ci, mname)
    mnames = @cls_meth_names[ci].split(";")
    j = 0
    while j < mnames.length
      if mnames[j] == mname
        return j
      end
      j = j + 1
    end
    -1
  end

  def method_params_decl(mi)
    pnames = @meth_param_names[mi].split(",")
    ptypes = @meth_param_types[mi].split(",")
    if pnames.length == 0
      return "void"
    end
    result = ""
    j = 0
    while j < pnames.length
      if j > 0
        result = result + ", "
      end
      pt = "int"
      if j < ptypes.length
        pt = ptypes[j]
      end
      result = result + c_type(pt) + " lv_" + pnames[j]
      j = j + 1
    end
    result
  end

  def find_init_class(ci)
    # Find which class in the chain has initialize
    init_idx = cls_find_method_direct(ci, "initialize")
    if init_idx >= 0
      return ci
    end
    if @cls_parents[ci] != ""
      pi = find_class_idx(@cls_parents[ci])
      if pi >= 0
        return find_init_class(pi)
      end
    end
    -1
  end

  def constructor_params_decl(ci)
    init_ci = find_init_class(ci)
    if init_ci < 0
      return "void"
    end
    init_idx = cls_find_method_direct(init_ci, "initialize")
    all_params = @cls_meth_params[init_ci].split("|")
    all_ptypes = @cls_meth_ptypes[init_ci].split("|")
    pnames = []
    ptypes = []
    if init_idx < all_params.length
      pnames = all_params[init_idx].split(",")
    end
    if init_idx < all_ptypes.length
      ptypes = all_ptypes[init_idx].split(",")
    end
    if pnames.length == 0
      return "void"
    end
    result = ""
    j = 0
    while j < pnames.length
      if j > 0
        result = result + ", "
      end
      pt = "int"
      if j < ptypes.length
        pt = ptypes[j]
      end
      result = result + c_type(pt) + " lv_" + pnames[j]
      j = j + 1
    end
    result
  end

  def init_params_decl(ci)
    init_ci = find_init_class(ci)
    if init_ci < 0
      return ""
    end
    init_idx = cls_find_method_direct(init_ci, "initialize")
    if init_idx < 0
      return ""
    end
    all_params = @cls_meth_params[init_ci].split("|")
    all_ptypes = @cls_meth_ptypes[init_ci].split("|")
    pnames = []
    ptypes = []
    if init_idx < all_params.length
      pnames = all_params[init_idx].split(",")
    end
    if init_idx < all_ptypes.length
      ptypes = all_ptypes[init_idx].split(",")
    end
    result = ""
    j = 0
    while j < pnames.length
      pt = "int"
      if j < ptypes.length
        pt = ptypes[j]
      end
      result = result + ", " + c_type(pt) + " lv_" + pnames[j]
      j = j + 1
    end
    result
  end

  def method_with_self_params(midx, all_params, all_ptypes)
    pnames = []
    ptypes = []
    if midx < all_params.length
      pnames = all_params[midx].split(",")
    end
    if midx < all_ptypes.length
      ptypes = all_ptypes[midx].split(",")
    end
    result = ""
    j = 0
    while j < pnames.length
      pt = "int"
      if j < ptypes.length
        pt = ptypes[j]
      end
      result = result + ", " + c_type(pt) + " lv_" + pnames[j]
      j = j + 1
    end
    result
  end

  def cls_method_params_decl(midx, all_params, all_ptypes)
    pnames = []
    ptypes = []
    if midx < all_params.length
      pnames = all_params[midx].split(",")
    end
    if midx < all_ptypes.length
      ptypes = all_ptypes[midx].split(",")
    end
    if pnames.length == 0
      return "void"
    end
    result = ""
    j = 0
    while j < pnames.length
      if j > 0
        result = result + ", "
      end
      pt = "int"
      if j < ptypes.length
        pt = ptypes[j]
      end
      result = result + c_type(pt) + " lv_" + pnames[j]
      j = j + 1
    end
    result
  end

  # ---- Emit class methods ----
  def emit_class_methods
    i = 0
    while i < @cls_names.length
      emit_constructor(i)
      mnames = @cls_meth_names[i].split(";")
      returns = @cls_meth_returns[i].split(";")
      all_params = @cls_meth_params[i].split("|")
      all_ptypes = @cls_meth_ptypes[i].split("|")
      bodies = @cls_meth_bodies[i].split(";")
      j = 0
      while j < mnames.length
        if mnames[j] != "initialize"
          rt = "int"
          if j < returns.length
            rt = returns[j]
          end
          bid = -1
          if j < bodies.length
            bid = bodies[j].to_i
          end
          pnames = []
          ptypes = []
          if j < all_params.length
            pnames = all_params[j].split(",")
          end
          if j < all_ptypes.length
            ptypes = all_ptypes[j].split(",")
          end
          emit_instance_method(i, mnames[j], pnames, ptypes, rt, bid)
        end
        j = j + 1
      end
      # Class methods
      cmnames = @cls_cmeth_names[i].split(";")
      cm_returns = @cls_cmeth_returns[i].split(";")
      cm_params = @cls_cmeth_params[i].split("|")
      cm_ptypes = @cls_cmeth_ptypes[i].split("|")
      cm_bodies = @cls_cmeth_bodies[i].split(";")
      j = 0
      while j < cmnames.length
        rt = "int"
        if j < cm_returns.length
          rt = cm_returns[j]
        end
        bid = -1
        if j < cm_bodies.length
          bid = cm_bodies[j].to_i
        end
        pnames = []
        ptypes = []
        if j < cm_params.length
          pnames = cm_params[j].split(",")
        end
        if j < cm_ptypes.length
          ptypes = cm_ptypes[j].split(",")
        end
        emit_class_level_method(i, cmnames[j], pnames, ptypes, rt, bid)
        j = j + 1
      end
      i = i + 1
    end
  end

  def emit_constructor(ci)
    cname = @cls_names[ci]
    init_idx = cls_find_method_direct(ci, "initialize")
    emit_raw("static sp_" + cname + " *sp_" + cname + "_new(" + constructor_params_decl(ci) + ") {")
    emit_raw("  SP_GC_SAVE();")
    emit_raw("  sp_" + cname + " *self = (sp_" + cname + " *)sp_gc_alloc(sizeof(sp_" + cname + "), NULL, NULL);")
    emit_raw("  SP_GC_ROOT(self);")

    init_ci = find_init_class(ci)
    actual_init_idx = -1
    if init_ci >= 0
      actual_init_idx = cls_find_method_direct(init_ci, "initialize")
    end

    if init_idx >= 0
      bodies = @cls_meth_bodies[ci].split(";")
      bid = -1
      if init_idx < bodies.length
        bid = bodies[init_idx].to_i
      end
      if bid == -2
        # Synthetic struct constructor
        all_params = @cls_meth_params[ci].split("|")
        pnames2 = []
        if init_idx < all_params.length
          pnames2 = all_params[init_idx].split(",")
        end
        sk = 0
        while sk < pnames2.length
          emit_raw("  self->" + pnames2[sk] + " = lv_" + pnames2[sk] + ";")
          sk = sk + 1
        end
      end
      if bid >= 0
        @current_class_idx = ci
        all_params = @cls_meth_params[ci].split("|")
        all_ptypes = @cls_meth_ptypes[ci].split("|")
        pnames = []
        ptypes = []
        if init_idx < all_params.length
          pnames = all_params[init_idx].split(",")
        end
        if init_idx < all_ptypes.length
          ptypes = all_ptypes[init_idx].split(",")
        end
        push_scope
        k = 0
        while k < pnames.length
          pt = "int"
          if k < ptypes.length
            pt = ptypes[k]
          end
          declare_var(pnames[k], pt)
          k = k + 1
        end
        stmts = get_stmts(bid)
        k = 0
        while k < stmts.length
          sid = stmts[k]
          if @nd_type[sid] == "SuperNode"
            if @cls_parents[ci] != ""
              pi = find_class_idx(@cls_parents[ci])
              if pi >= 0
                super_args = ""
                args_id = @nd_arguments[sid]
                if args_id >= 0
                  arg_ids = get_args(args_id)
                  ak = 0
                  while ak < arg_ids.length
                    if ak > 0
                      super_args = super_args + ", "
                    end
                    super_args = super_args + compile_expr(arg_ids[ak])
                    ak = ak + 1
                  end
                end
                emit_raw("  sp_" + @cls_parents[ci] + "_initialize((sp_" + @cls_parents[ci] + " *)self" + (super_args != "" ? ", " + super_args : "") + ");")
              end
            end
          end
          if @nd_type[sid] == "InstanceVariableWriteNode"
            ivar = sanitize_ivar(@nd_name[sid])
            val = compile_expr(@nd_expression[sid])
            emit_raw("  self->" + ivar + " = " + val + ";")
          end
          k = k + 1
        end
        pop_scope
        @current_class_idx = -1
      end
    else
      # No own initialize - call parent's if it exists
      if init_ci >= 0
        if init_ci != ci
          parent_name = @cls_names[init_ci]
          # Build param forwarding: forward all constructor params to parent init
          pi_params = @cls_meth_params[init_ci].split("|")
          pi_idx = cls_find_method_direct(init_ci, "initialize")
          pnames = []
          if pi_idx >= 0
            if pi_idx < pi_params.length
              pnames = pi_params[pi_idx].split(",")
            end
          end
          fwd = ""
          pk = 0
          while pk < pnames.length
            if pk > 0
              fwd = fwd + ", "
            end
            fwd = fwd + "lv_" + pnames[pk]
            pk = pk + 1
          end
          emit_raw("  sp_" + parent_name + "_initialize((sp_" + parent_name + " *)self" + (fwd != "" ? ", " + fwd : "") + ");")
        end
      end
    end

    emit_raw("  SP_GC_RESTORE();")
    emit_raw("  return self;")
    emit_raw("}")
    emit_raw("")

    # Initialize function (for super calls)
    if init_idx >= 0
      emit_raw("static void sp_" + cname + "_initialize(sp_" + cname + " *self" + init_params_decl(ci) + ") {")
      bodies = @cls_meth_bodies[ci].split(";")
      bid = -1
      if init_idx < bodies.length
        bid = bodies[init_idx].to_i
      end
      if bid >= 0
        @current_class_idx = ci
        all_params = @cls_meth_params[ci].split("|")
        all_ptypes = @cls_meth_ptypes[ci].split("|")
        pnames = []
        ptypes = []
        if init_idx < all_params.length
          pnames = all_params[init_idx].split(",")
        end
        if init_idx < all_ptypes.length
          ptypes = all_ptypes[init_idx].split(",")
        end
        push_scope
        k = 0
        while k < pnames.length
          pt = "int"
          if k < ptypes.length
            pt = ptypes[k]
          end
          declare_var(pnames[k], pt)
          k = k + 1
        end
        stmts = get_stmts(bid)
        k = 0
        while k < stmts.length
          sid = stmts[k]
          if @nd_type[sid] == "InstanceVariableWriteNode"
            ivar = sanitize_ivar(@nd_name[sid])
            val = compile_expr(@nd_expression[sid])
            emit_raw("  self->" + ivar + " = " + val + ";")
          end
          k = k + 1
        end
        pop_scope
        @current_class_idx = -1
      end
      emit_raw("}")
      emit_raw("")
    end
  end

  def emit_instance_method(ci, mname, pnames, ptypes, rt, bid)
    cname = @cls_names[ci]
    @current_class_idx = ci
    @current_method_name = mname
    @current_method_return = rt
    @indent = 1

    midx = cls_find_method_direct(ci, mname)
    if midx >= 0
      if cls_method_has_yield(ci, midx) == 1
        @in_yield_method = 1
      else
        @in_yield_method = 0
      end
    end

    yp = ""
    if @in_yield_method == 1
      yp = yield_params_suffix_cls(ci, midx)
    end
    emit_raw("static " + c_type(rt) + " sp_" + cname + "_" + sanitize_name(mname) + "(sp_" + cname + " *self" + build_params_str(pnames, ptypes) + yp + ") {")

    push_scope
    j = 0
    while j < pnames.length
      pt = "int"
      if j < ptypes.length
        pt = ptypes[j]
      end
      declare_var(pnames[j], pt)
      j = j + 1
    end

    if bid >= 0
      declare_method_locals(bid, pnames)
      compile_body_return(bid, rt)
    end

    pop_scope
    @current_class_idx = -1
    @current_method_name = ""
    @in_yield_method = 0
    @indent = 0
    emit_raw("}")
    emit_raw("")
  end

  def emit_class_level_method(ci, mname, pnames, ptypes, rt, bid)
    cname = @cls_names[ci]
    @current_class_idx = ci
    @current_method_name = mname
    @current_method_return = rt
    @indent = 1

    emit_raw("static " + c_type(rt) + " sp_" + cname + "_cls_" + sanitize_name(mname) + "(" + build_params_decl(pnames, ptypes) + ") {")

    push_scope
    j = 0
    while j < pnames.length
      pt = "int"
      if j < ptypes.length
        pt = ptypes[j]
      end
      declare_var(pnames[j], pt)
      j = j + 1
    end

    if bid >= 0
      declare_method_locals(bid, pnames)
      compile_body_return(bid, rt)
    end

    pop_scope
    @current_class_idx = -1
    @current_method_name = ""
    @indent = 0
    emit_raw("}")
    emit_raw("")
  end

  def build_params_str(pnames, ptypes)
    result = ""
    j = 0
    while j < pnames.length
      pt = "int"
      if j < ptypes.length
        pt = ptypes[j]
      end
      result = result + ", " + c_type(pt) + " lv_" + pnames[j]
      j = j + 1
    end
    result
  end

  def build_params_decl(pnames, ptypes)
    if pnames.length == 0
      return "void"
    end
    result = ""
    j = 0
    while j < pnames.length
      if j > 0
        result = result + ", "
      end
      pt = "int"
      if j < ptypes.length
        pt = ptypes[j]
      end
      result = result + c_type(pt) + " lv_" + pnames[j]
      j = j + 1
    end
    result
  end

  # ---- Emit top-level methods ----
  def emit_toplevel_methods
    i = 0
    while i < @meth_names.length
      emit_toplevel_method(i)
      i = i + 1
    end
  end

  def emit_toplevel_method(mi)
    @current_method_name = @meth_names[mi]
    @current_method_return = @meth_return_types[mi]
    @indent = 1
    @in_main = 0
    if @meth_has_yield[mi] == 1
      @in_yield_method = 1
    else
      @in_yield_method = 0
    end

    pnames = @meth_param_names[mi].split(",")
    ptypes = @meth_param_types[mi].split(",")

    yp = ""
    if @meth_has_yield[mi] == 1
      yp = yield_params_suffix(mi)
    end
    emit_raw("static " + c_type(@meth_return_types[mi]) + " sp_" + sanitize_name(@meth_names[mi]) + "(" + method_params_decl(mi) + yp + ") {")

    push_scope
    j = 0
    while j < pnames.length
      pt = "int"
      if j < ptypes.length
        pt = ptypes[j]
      end
      declare_var(pnames[j], pt)
      j = j + 1
    end

    bid = @meth_body_ids[mi]
    if bid >= 0
      declare_method_locals(bid, pnames)
      compile_body_return(bid, @meth_return_types[mi])
    end

    pop_scope
    @current_method_name = ""
    @in_yield_method = 0
    @indent = 0
    emit_raw("}")
    emit_raw("")
  end

  def declare_method_locals(bid, params)
    lnames = []
    ltypes = []
    scan_locals(bid, lnames, ltypes, params)
    # Declare all locals first so block param inference can see them
    j = 0
    while j < lnames.length
      declare_var(lnames[j], ltypes[j])
      j = j + 1
    end
    # Second pass: re-scan with types now in scope for better block param inference
    lnames2 = []
    ltypes2 = []
    scan_locals(bid, lnames2, ltypes2, params)
    # Update types that may have improved
    j = 0
    while j < lnames2.length
      k = 0
      while k < lnames.length
        if lnames[k] == lnames2[j]
          if ltypes[k] == "int"
            if ltypes2[j] != "int"
              ltypes[k] = ltypes2[j]
              set_var_type(lnames[k], ltypes2[j])
            end
          end
        end
        k = k + 1
      end
      j = j + 1
    end
    # Emit declarations
    j = 0
    while j < lnames.length
      emit("  " + c_type(ltypes[j]) + " lv_" + lnames[j] + " = " + c_default_val(ltypes[j]) + ";")
      j = j + 1
    end
  end

  def scan_locals(nid, names, types, params)
    if nid < 0
      return
    end
    if @nd_type[nid] == "MultiWriteNode"
      targets = parse_id_list(@nd_targets[nid])
      k = 0
      while k < targets.length
        tid = targets[k]
        if @nd_type[tid] == "LocalVariableTargetNode"
          lname = @nd_name[tid]
          if not_in(lname, names) == 1
            if not_in(lname, params) == 1
              names.push(lname)
              types.push("int")
            end
          end
        end
        k = k + 1
      end
      if @nd_expression[nid] >= 0
        scan_locals(@nd_expression[nid], names, types, params)
      end
      return
    end
    if @nd_type[nid] == "LocalVariableWriteNode"
      lname = @nd_name[nid]
      if not_in(lname, names) == 1
        if not_in(lname, params) == 1
          names.push(lname)
          types.push(infer_type(@nd_expression[nid]))
        end
      else
        if not_in(lname, params) == 1
          # Check if type changed
          at = infer_type(@nd_expression[nid])
          ki = 0
          while ki < names.length
            if names[ki] == lname
              if types[ki] != at
                if types[ki] != "poly"
                  types[ki] = "poly"
                  @needs_rb_value = 1
                end
              end
            end
            ki = ki + 1
          end
        end
      end
    end
    if @nd_type[nid] == "LocalVariableOperatorWriteNode"
      lname = @nd_name[nid]
      if not_in(lname, names) == 1
        if not_in(lname, params) == 1
          names.push(lname)
          types.push("int")
        end
      end
    end
    if @nd_type[nid] == "ForNode"
      tgt = @nd_target[nid]
      if tgt >= 0
        if @nd_type[tgt] == "LocalVariableTargetNode"
          lname = @nd_name[tgt]
          if not_in(lname, names) == 1
            if not_in(lname, params) == 1
              names.push(lname)
              types.push("int")
            end
          end
        end
      end
    end
    # Rescue reference (=> e) needs to be declared as a local
    if @nd_type[nid] == "RescueNode"
      ref = @nd_reference[nid]
      if ref >= 0
        lname = @nd_name[ref]
        if not_in(lname, names) == 1
          if not_in(lname, params) == 1
            names.push(lname)
            types.push("string")
          end
        end
      end
    end
    # Block parameters need to be declared as locals
    if @nd_type[nid] == "CallNode"
      blk = @nd_block[nid]
      if blk >= 0
        bp = @nd_parameters[blk]
        if bp >= 0
          inner = @nd_parameters[bp]
          if inner >= 0
            reqs = parse_id_list(@nd_requireds[inner])
            bk = 0
            while bk < reqs.length
              bname = @nd_name[reqs[bk]]
              if not_in(bname, names) == 1
                if not_in(bname, params) == 1
                  names.push(bname)
                  # Infer type from receiver context
                  recv_type = ""
                  if @nd_receiver[nid] >= 0
                    recv_type = infer_type(@nd_receiver[nid])
                    # If type is int and receiver is local var, check names array
                    if recv_type == "int"
                      if @nd_type[@nd_receiver[nid]] == "LocalVariableReadNode"
                        rname = @nd_name[@nd_receiver[nid]]
                        ri = 0
                        while ri < names.length
                          if names[ri] == rname
                            recv_type = types[ri]
                          end
                          ri = ri + 1
                        end
                      end
                    end
                  end
                  mname = @nd_name[nid]
                  if mname == "each"
                    if recv_type == "int_array"
                      if bk == 0
                        types.push("int")
                      else
                        types.push("int")
                      end
                    else
                      if recv_type == "str_array"
                        types.push("string")
                      else
                        if recv_type == "str_int_hash"
                          if bk == 0
                            types.push("string")
                          else
                            types.push("int")
                          end
                        else
                          if recv_type == "str_str_hash"
                            types.push("string")
                          else
                            types.push("int")
                          end
                        end
                      end
                    end
                  else
                    if mname == "times"
                      types.push("int")
                    else
                      if mname == "upto"
                        types.push("int")
                      else
                        if mname == "downto"
                          types.push("int")
                        else
                          if mname == "reduce"
                            types.push("int")
                          else
                            if mname == "inject"
                              types.push("int")
                            else
                              if mname == "reject"
                                types.push("int")
                              else
                                types.push("int")
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
              bk = bk + 1
            end
          end
        end
      end
    end
    # Recurse
    scan_locals_children(nid, names, types, params)
  end

  def scan_locals_children(nid, names, types, params)
    if @nd_body[nid] >= 0
      scan_locals(@nd_body[nid], names, types, params)
    end
    stmts = parse_id_list(@nd_stmts[nid])
    k = 0
    while k < stmts.length
      scan_locals(stmts[k], names, types, params)
      k = k + 1
    end
    if @nd_expression[nid] >= 0
      scan_locals(@nd_expression[nid], names, types, params)
    end
    if @nd_predicate[nid] >= 0
      scan_locals(@nd_predicate[nid], names, types, params)
    end
    if @nd_subsequent[nid] >= 0
      scan_locals(@nd_subsequent[nid], names, types, params)
    end
    if @nd_else_clause[nid] >= 0
      scan_locals(@nd_else_clause[nid], names, types, params)
    end
    if @nd_arguments[nid] >= 0
      scan_locals(@nd_arguments[nid], names, types, params)
    end
    args = parse_id_list(@nd_args[nid])
    k = 0
    while k < args.length
      scan_locals(args[k], names, types, params)
      k = k + 1
    end
    conds = parse_id_list(@nd_conditions[nid])
    k = 0
    while k < conds.length
      scan_locals(conds[k], names, types, params)
      k = k + 1
    end
    elems = parse_id_list(@nd_elements[nid])
    k = 0
    while k < elems.length
      scan_locals(elems[k], names, types, params)
      k = k + 1
    end
    if @nd_left[nid] >= 0
      scan_locals(@nd_left[nid], names, types, params)
    end
    if @nd_right[nid] >= 0
      scan_locals(@nd_right[nid], names, types, params)
    end
    if @nd_block[nid] >= 0
      scan_locals(@nd_block[nid], names, types, params)
    end
    if @nd_receiver[nid] >= 0
      scan_locals(@nd_receiver[nid], names, types, params)
    end
    if @nd_collection[nid] >= 0
      scan_locals(@nd_collection[nid], names, types, params)
    end
    if @nd_rescue_clause[nid] >= 0
      scan_locals(@nd_rescue_clause[nid], names, types, params)
    end
    if @nd_ensure_clause[nid] >= 0
      scan_locals(@nd_ensure_clause[nid], names, types, params)
    end
  end

  def not_in(name, arr)
    k = 0
    while k < arr.length
      if arr[k] == name
        return 0
      end
      k = k + 1
    end
    1
  end

  # ---- Main emission ----
  def emit_main
    stmts = get_body_stmts(@root_id)
    emit_raw("typedef struct{const char**data;mrb_int len;}sp_Argv;")
    emit_raw("static sp_Argv sp_argv;")
    emit_raw("")
    emit_raw("int main(int argc,char**argv){")
    emit_raw("  sp_argv.data=(const char**)(argv+1);sp_argv.len=argc-1;")

    @in_main = 1
    @indent = 1
    push_scope

    # Pre-declare main locals
    lnames = []
    ltypes = []
    empty_params = []
    i = 0
    while i < stmts.length
      sid = stmts[i]
      if @nd_type[sid] != "DefNode"
        if @nd_type[sid] != "ClassNode"
          if @nd_type[sid] != "ConstantWriteNode"
            scan_locals(sid, lnames, ltypes, empty_params)
          end
        end
      end
      i = i + 1
    end

    # Declare vars for second pass to resolve dependent types
    j = 0
    while j < lnames.length
      declare_var(lnames[j], ltypes[j])
      j = j + 1
    end
    # Second pass with vars in scope
    lnames2 = []
    ltypes2 = []
    i = 0
    while i < stmts.length
      sid = stmts[i]
      if @nd_type[sid] != "DefNode"
        if @nd_type[sid] != "ClassNode"
          if @nd_type[sid] != "ConstantWriteNode"
            if @nd_type[sid] != "ModuleNode"
              scan_locals(sid, lnames2, ltypes2, empty_params)
            end
          end
        end
      end
      i = i + 1
    end
    # Update types that improved in second pass
    j = 0
    while j < lnames2.length
      k = 0
      while k < lnames.length
        if lnames[k] == lnames2[j]
          if ltypes[k] == "int"
            if ltypes2[j] != "int"
              ltypes[k] = ltypes2[j]
              set_var_type(lnames[k], ltypes2[j])
            end
          end
        end
        k = k + 1
      end
      j = j + 1
    end

    vol = ""
    if @needs_setjmp == 1
      vol = "volatile "
    end
    j = 0
    while j < lnames.length
      ctp = c_type(ltypes[j])
      if type_is_pointer(ltypes[j]) == 1
        emit("  " + vol + ctp + "lv_" + lnames[j] + " = NULL;")
        emit("  SP_GC_ROOT(lv_" + lnames[j] + ");")
      else
        emit("  " + vol + ctp + " lv_" + lnames[j] + " = " + c_default_val(ltypes[j]) + ";")
      end
      j = j + 1
    end

    # Constants
    i = 0
    while i < @const_names.length
      ctp = c_type(@const_types[i])
      val = compile_expr(@const_expr_ids[i])
      emit("  " + ctp + " cst_" + @const_names[i] + " = " + val + ";")
      i = i + 1
    end

    emit_raw("")

    # Compile main statements
    i = 0
    while i < stmts.length
      sid = stmts[i]
      if @nd_type[sid] != "DefNode"
        if @nd_type[sid] != "ClassNode"
          if @nd_type[sid] != "ConstantWriteNode"
            compile_stmt(sid)
          end
        end
      end
      i = i + 1
    end

    emit_raw("  return 0;")
    emit_raw("}")

    pop_scope
    @in_main = 0
  end

  # ---- Expression compiler ----
  def compile_expr(nid)
    if nid < 0
      return "0"
    end
    t = @nd_type[nid]
    if t == "IntegerNode"
      return @nd_value[nid].to_s
    end
    if t == "FloatNode"
      return @nd_content[nid]
    end
    if t == "StringNode"
      return c_string_literal(@nd_content[nid])
    end
    if t == "SymbolNode"
      return c_string_literal(@nd_content[nid])
    end
    if t == "InterpolatedStringNode"
      return compile_interpolated(nid)
    end
    if t == "TrueNode"
      return "TRUE"
    end
    if t == "FalseNode"
      return "FALSE"
    end
    if t == "NilNode"
      return "0"
    end
    if t == "SelfNode"
      return "self"
    end
    if t == "LocalVariableReadNode"
      return "lv_" + @nd_name[nid]
    end
    if t == "InstanceVariableReadNode"
      return "self->" + sanitize_ivar(@nd_name[nid])
    end
    if t == "ConstantReadNode"
      if @nd_name[nid] == "ARGV"
        return "sp_argv"
      end
      ci = find_const_idx(@nd_name[nid])
      if ci >= 0
        return "cst_" + @nd_name[nid]
      end
      return @nd_name[nid]
    end
    if t == "ConstantPathNode"
      if @nd_receiver[nid] >= 0
        rname = @nd_name[@nd_receiver[nid]]
        nname = @nd_name[nid]
        cpname = rname + "_" + nname
        ci = find_const_idx(cpname)
        if ci >= 0
          return "cst_" + cpname
        end
        # Built-in constants
        if rname == "Float"
          if nname == "INFINITY"
            return "(1.0/0.0)"
          end
          if nname == "NAN"
            return "(0.0/0.0)"
          end
        end
        if rname == "Integer"
          if nname == "MAX"
            return "INT64_MAX"
          end
        end
        return cpname
      end
      return @nd_name[nid]
    end
    if t == "CallNode"
      return compile_call_expr(nid)
    end
    if t == "IfNode"
      return compile_if_expr(nid)
    end
    if t == "UnlessNode"
      return compile_unless_expr(nid)
    end
    if t == "AndNode"
      return "(" + compile_expr(@nd_left[nid]) + " && " + compile_expr(@nd_right[nid]) + ")"
    end
    if t == "OrNode"
      return "(" + compile_expr(@nd_left[nid]) + " || " + compile_expr(@nd_right[nid]) + ")"
    end
    if t == "ParenthesesNode"
      body = @nd_body[nid]
      if body >= 0
        stmts = get_stmts(body)
        if stmts.length > 0
          return compile_expr(stmts[stmts.length - 1])
        end
      end
      return "0"
    end
    if t == "ArrayNode"
      return compile_array_literal(nid)
    end
    if t == "HashNode"
      return compile_hash_literal(nid)
    end
    if t == "RangeNode"
      return "sp_range_new(" + compile_expr(@nd_left[nid]) + ", " + compile_expr(@nd_right[nid]) + ")"
    end
    if t == "DefinedNode"
      return "\"expression\""
    end
    if t == "RescueModifierNode"
      @needs_setjmp = 1
      tmp = new_temp
      rt = infer_type(@nd_else_clause[nid])
      emit("  " + c_type(rt) + " " + tmp + " = " + c_default_val(rt) + ";")
      emit("  sp_exc_top++;")
      emit("  if (setjmp(sp_exc_stack[sp_exc_top-1]) == 0) {")
      emit("    " + tmp + " = " + compile_expr(@nd_expression[nid]) + ";")
      emit("    sp_exc_top--;")
      emit("  } else {")
      emit("    sp_exc_top--;")
      emit("    " + tmp + " = " + compile_expr(@nd_else_clause[nid]) + ";")
      emit("  }")
      return tmp
    end
    if t == "XStringNode"
      @needs_file_io = 1
      return "sp_backtick(" + c_string_literal(@nd_content[nid]) + ")"
    end
    if t == "InterpolatedXStringNode"
      @needs_file_io = 1
      @needs_string_helpers = 1
      interp = compile_interpolated(nid)
      return "sp_backtick(" + interp + ")"
    end
    if t == "GlobalVariableReadNode"
      gname = @nd_name[nid]
      if gname == "$stderr"
        return "0"
      end
      if gname == "$stdout"
        return "0"
      end
      if gname == "$?"
        return "sp_last_status"
      end
      return "0"
    end
    if t == "SourceLineNode"
      return @nd_value[nid].to_s
    end
    if t == "ArgumentsNode"
      arg_ids = parse_id_list(@nd_args[nid])
      if arg_ids.length > 0
        return compile_expr(arg_ids[0])
      end
      return "0"
    end
    if t == "StatementsNode"
      stmts = parse_id_list(@nd_stmts[nid])
      if stmts.length > 0
        return compile_expr(stmts[stmts.length - 1])
      end
      return "0"
    end
    if t == "EmbeddedStatementsNode"
      body = @nd_body[nid]
      if body >= 0
        stmts = get_stmts(body)
        if stmts.length > 0
          return compile_expr(stmts[0])
        end
      end
      return "0"
    end
    "0"
  end

  def c_string_literal(s)
    result = "\""
    i = 0
    while i < s.length
      ch = s[i]
      if ch == "\\"
        # Check for Ruby escape sequences
        if i + 1 < s.length
          nch = s[i + 1]
          if nch == "n"
            result = result + "\\n"
            i = i + 2
          else
            if nch == "t"
              result = result + "\\t"
              i = i + 2
            else
              if nch == "r"
                result = result + "\\r"
                i = i + 2
              else
                if nch == "\\"
                  result = result + "\\\\"
                  i = i + 2
                else
                  if nch == "\""
                    result = result + "\\\""
                    i = i + 2
                  else
                    result = result + "\\\\"
                    i = i + 1
                  end
                end
              end
            end
          end
        else
          result = result + "\\\\"
          i = i + 1
        end
      else
        if ch == "\""
          result = result + "\\\""
        else
          if ch == "\n"
            result = result + "\\n"
          else
            if ch == "\r"
              result = result + "\\r"
            else
              if ch == "\t"
                result = result + "\\t"
              else
                result = result + ch
              end
            end
          end
        end
        i = i + 1
      end
    end
    result + "\""
  end

  def compile_interpolated(nid)
    @needs_string_helpers = 1
    parts = parse_id_list(@nd_parts[nid])
    if parts.length == 0
      return "\"\""
    end
    fmt = ""
    arg_exprs = []
    i = 0
    while i < parts.length
      pid = parts[i]
      if @nd_type[pid] == "StringNode"
        fmt = fmt + escape_c_format(@nd_content[pid])
      else
        if @nd_type[pid] == "EmbeddedStatementsNode"
          body = @nd_body[pid]
          if body >= 0
            stmts = get_stmts(body)
            if stmts.length > 0
              inner = stmts[0]
              it = infer_type(inner)
              if it == "int"
                fmt = fmt + "%lld"
                arg_exprs.push("(long long)" + compile_expr(inner))
              else
                if it == "float"
                  fmt = fmt + "%g"
                  arg_exprs.push(compile_expr(inner))
                else
                  if it == "string"
                    fmt = fmt + "%s"
                    arg_exprs.push(compile_expr(inner))
                  else
                    if it == "bool"
                      fmt = fmt + "%s"
                      arg_exprs.push("(" + compile_expr(inner) + " ? \"true\" : \"false\")")
                    else
                      if it == "poly"
                        fmt = fmt + "%s"
                        arg_exprs.push("sp_poly_to_s(" + compile_expr(inner) + ")")
                      else
                        fmt = fmt + "%lld"
                        arg_exprs.push("(long long)" + compile_expr(inner))
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
      i = i + 1
    end
    result = "sp_sprintf(\"" + fmt + "\""
    j = 0
    while j < arg_exprs.length
      result = result + ", " + arg_exprs[j]
      j = j + 1
    end
    result + ")"
  end

  def escape_c_format(s)
    result = ""
    i = 0
    while i < s.length
      ch = s[i]
      if ch == "%"
        result = result + "%%"
      else
        if ch == "\\"
          result = result + "\\\\"
        else
          if ch == "\""
            result = result + "\\\""
          else
            if ch == "\n"
              result = result + "\\n"
            else
              if ch == "\t"
                result = result + "\\t"
              else
                result = result + ch
              end
            end
          end
        end
      end
      i = i + 1
    end
    result
  end

  def compile_arg0(nid)
    args_id = @nd_arguments[nid]
    if args_id >= 0
      arg_ids = get_args(args_id)
      if arg_ids.length > 0
        return compile_expr(arg_ids[0])
      end
    end
    "0"
  end

  def compile_call_expr(nid)
    mname = @nd_name[nid]
    recv = @nd_receiver[nid]

    # No receiver
    if recv < 0
      # catch as expression
      if mname == "catch"
        if @nd_block[nid] >= 0
          return compile_catch_expr(nid)
        end
      end
      if mname == "block_given?"
        if @in_yield_method == 1
          return "(_block != NULL)"
        end
        return "0"
      end
      if mname == "__method__"
        return "\"" + @current_method_name + "\""
      end
      if mname == "p"
        # p(val) -> puts(val.inspect) - for simplicity, same as puts
        compile_puts(nid)
        return "0"
      end
      if mname == "srand"
        emit("  srand((unsigned)" + compile_arg0(nid) + ");")
        return "0"
      end
      if mname == "rand"
        args_id = @nd_arguments[nid]
        if args_id >= 0
          return "((mrb_int)(rand() % (int)" + compile_arg0(nid) + "))"
        end
        return "((mrb_int)rand())"
      end
      if mname == "raise"
        @needs_setjmp = 1
        args_id = @nd_arguments[nid]
        if args_id >= 0
          arg_ids = get_args(args_id)
          if arg_ids.length >= 1
            emit("  sp_raise(" + compile_expr(arg_ids[0]) + ");")
          end
        else
          emit("  sp_raise(\"RuntimeError\");")
        end
        return "0"
      end
      if mname == "format"
        @needs_string_helpers = 1
        return compile_sprintf_call(nid)
      end
      if mname == "sprintf"
        @needs_string_helpers = 1
        return compile_sprintf_call(nid)
      end
      if mname == "putc"
        args_id = @nd_arguments[nid]
        if args_id >= 0
          arg_ids = get_args(args_id)
          if arg_ids.length > 0
            at = infer_type(arg_ids[0])
            if at == "int"
              return "(putchar((char)" + compile_expr(arg_ids[0]) + "), 0)"
            else
              return "(putchar(" + compile_expr(arg_ids[0]) + "[0]), 0)"
            end
          end
        end
        return "0"
      end
      mi = find_method_idx(mname)
      if mi >= 0
        yargs = ""
        if @meth_has_yield[mi] == 1
          yargs = ", NULL, NULL"
        end
        return "sp_" + sanitize_name(mname) + "(" + compile_call_args_with_defaults(nid, mi) + yargs + ")"
      end
      if @current_class_idx >= 0
        cidx = cls_find_method(@current_class_idx, mname)
        if cidx >= 0
          ca = compile_call_args(nid)
          cname = @cls_names[@current_class_idx]
          owner = find_method_owner(@current_class_idx, mname)
          if ca != ""
            return "sp_" + owner + "_" + sanitize_name(mname) + "(self, " + ca + ")"
          else
            return "sp_" + owner + "_" + sanitize_name(mname) + "(self)"
          end
        end
      end
      return "0"
    end

    # Check if operator is on an object with custom method
    if is_operator_name(mname) == 1
      lt = infer_type(recv)
      if is_obj_type(lt) == 1
        cname = lt[4, lt.length - 4]
        ci = find_class_idx(cname)
        if ci >= 0
          owner = find_method_owner(ci, mname)
          if owner != ""
            ca = compile_call_args(nid)
            rc = compile_expr(recv)
            if owner == cname
              if ca != ""
                return "sp_" + owner + "_" + sanitize_name(mname) + "(" + rc + ", " + ca + ")"
              else
                return "sp_" + owner + "_" + sanitize_name(mname) + "(" + rc + ")"
              end
            else
              if ca != ""
                return "sp_" + owner + "_" + sanitize_name(mname) + "((sp_" + owner + " *)" + rc + ", " + ca + ")"
              else
                return "sp_" + owner + "_" + sanitize_name(mname) + "((sp_" + owner + " *)" + rc + ")"
              end
            end
          end
        end
      end
    end

    # Operators
    if mname == "**"
      lt = infer_type(recv)
      if lt == "int"
        return "((mrb_int)pow((double)" + compile_expr(recv) + ", (double)" + compile_arg0(nid) + "))"
      end
      return "pow(" + compile_expr(recv) + ", " + compile_arg0(nid) + ")"
    end
    if mname == "+"
      lt = infer_type(recv)
      if lt == "string"
        @needs_string_helpers = 1
        return "sp_str_concat(" + compile_expr(recv) + ", " + compile_arg0(nid) + ")"
      end
      if lt == "poly"
        @needs_rb_value = 1
        @needs_string_helpers = 1
        return "sp_poly_add(" + compile_expr(recv) + ", " + box_expr_to_poly(@nd_arguments[nid] >= 0 ? get_args(@nd_arguments[nid])[0] : -1) + ")"
      end
      return "(" + compile_expr(recv) + " + " + compile_arg0(nid) + ")"
    end
    if mname == "-"
      lt = infer_type(recv)
      args_id = @nd_arguments[nid]
      if args_id < 0
        return "(-" + compile_expr(recv) + ")"
      end
      if lt == "poly"
        @needs_rb_value = 1
        return "sp_poly_sub(" + compile_expr(recv) + ", " + box_expr_to_poly(get_args(args_id)[0]) + ")"
      end
      return "(" + compile_expr(recv) + " - " + compile_arg0(nid) + ")"
    end
    if mname == "*"
      lt = infer_type(recv)
      if lt == "string"
        @needs_string_helpers = 1
        return "sp_str_repeat(" + compile_expr(recv) + ", " + compile_arg0(nid) + ")"
      end
      if lt == "poly"
        @needs_rb_value = 1
        return "sp_poly_mul(" + compile_expr(recv) + ", " + box_expr_to_poly(get_args(@nd_arguments[nid])[0]) + ")"
      end
      return "(" + compile_expr(recv) + " * " + compile_arg0(nid) + ")"
    end
    if mname == "/"
      lt = infer_type(recv)
      if lt == "float"
        return "(" + compile_expr(recv) + " / " + compile_arg0(nid) + ")"
      end
      return "sp_idiv(" + compile_expr(recv) + ", " + compile_arg0(nid) + ")"
    end
    if mname == "%"
      return "sp_imod(" + compile_expr(recv) + ", " + compile_arg0(nid) + ")"
    end
    if mname == "<"
      lt = infer_type(recv)
      if lt == "string"
        return "(strcmp(" + compile_expr(recv) + ", " + compile_arg0(nid) + ") < 0)"
      end
      return "(" + compile_expr(recv) + " < " + compile_arg0(nid) + ")"
    end
    if mname == ">"
      lt = infer_type(recv)
      if lt == "poly"
        @needs_rb_value = 1
        return "sp_poly_gt(" + compile_expr(recv) + ", " + box_expr_to_poly(get_args(@nd_arguments[nid])[0]) + ")"
      end
      return "(" + compile_expr(recv) + " > " + compile_arg0(nid) + ")"
    end
    if mname == "<="
      return "(" + compile_expr(recv) + " <= " + compile_arg0(nid) + ")"
    end
    if mname == ">="
      return "(" + compile_expr(recv) + " >= " + compile_arg0(nid) + ")"
    end
    if mname == "=="
      return compile_eq(nid, "==")
    end
    if mname == "!="
      return compile_eq(nid, "!=")
    end
    if mname == "!"
      return "(!" + compile_expr(recv) + ")"
    end
    if mname == "<<"
      lt = infer_type(recv)
      if lt == "string"
        @needs_string_helpers = 1
        return "sp_str_concat(" + compile_expr(recv) + ", " + compile_arg0(nid) + ")"
      end
      return "(" + compile_expr(recv) + " << " + compile_arg0(nid) + ")"
    end
    if mname == ">>"
      return "(" + compile_expr(recv) + " >> " + compile_arg0(nid) + ")"
    end
    if mname == "&"
      return "(" + compile_expr(recv) + " & " + compile_arg0(nid) + ")"
    end
    if mname == "|"
      return "(" + compile_expr(recv) + " | " + compile_arg0(nid) + ")"
    end
    if mname == "^"
      return "(" + compile_expr(recv) + " ^ " + compile_arg0(nid) + ")"
    end
    if mname == "~"
      return "(~" + compile_expr(recv) + ")"
    end

    # .new
    if mname == "new"
      if @nd_type[recv] == "ConstantReadNode"
        cname = @nd_name[recv]
        if cname == "Array"
          @needs_int_array = 1
          @needs_gc = 1
          return "sp_IntArray_new()"
        end
        if cname == "Hash"
          @needs_str_int_hash = 1
          @needs_gc = 1
          return "sp_StrIntHash_new()"
        end
        ci = find_class_idx(cname)
        if ci >= 0
          return "sp_" + cname + "_new(" + compile_constructor_args(ci, nid) + ")"
        end
      end
    end

    recv_type = infer_type(recv)
    rc = compile_expr(recv)

    # String methods
    if recv_type == "string"
      @needs_string_helpers = 1
      if mname == "length"
        return "(mrb_int)strlen(" + rc + ")"
      end
      if mname == "to_i"
        return "((mrb_int)atoll(" + rc + "))"
      end
      if mname == "to_f"
        return "atof(" + rc + ")"
      end
      if mname == "upcase"
        return "sp_str_upcase(" + rc + ")"
      end
      if mname == "downcase"
        return "sp_str_downcase(" + rc + ")"
      end
      if mname == "strip"
        return "sp_str_strip(" + rc + ")"
      end
      if mname == "chomp"
        return "sp_str_chomp(" + rc + ")"
      end
      if mname == "include?"
        return "sp_str_include(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "start_with?"
        return "sp_str_start_with(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "end_with?"
        return "sp_str_end_with(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "split"
        @needs_str_array = 1
        return "sp_str_split(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "gsub"
        args_id = @nd_arguments[nid]
        arg1 = "\"\""
        if args_id >= 0
          a = get_args(args_id)
          if a.length >= 2
            arg1 = compile_expr(a[1])
          end
        end
        return "sp_str_gsub(" + rc + ", " + compile_arg0(nid) + ", " + arg1 + ")"
      end
      if mname == "index"
        return "sp_str_index(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "[]"
        args_id = @nd_arguments[nid]
        if args_id >= 0
          a = get_args(args_id)
          if a.length >= 1
            if @nd_type[a[0]] == "RangeNode"
              # s[1..3]
              left = compile_expr(@nd_left[a[0]])
              right = compile_expr(@nd_right[a[0]])
              return "sp_str_sub_range(" + rc + ", " + left + ", " + right + " - " + left + " + 1)"
            end
            if a.length >= 2
              # s[0, 2]
              return "sp_str_sub_range(" + rc + ", " + compile_expr(a[0]) + ", " + compile_expr(a[1]) + ")"
            end
          end
        end
        return "sp_str_sub_range(" + rc + ", " + compile_arg0(nid) + ", 1)"
      end
      if mname == "reverse"
        @needs_string_helpers = 1
        return "sp_str_reverse(" + rc + ")"
      end
      if mname == "freeze"
        return rc
      end
      if mname == "frozen?"
        return "TRUE"
      end
      if mname == "to_sym"
        return rc
      end
      if mname == "ord"
        return "((mrb_int)(unsigned char)" + rc + "[0])"
      end
      if mname == "sub"
        args_id = @nd_arguments[nid]
        arg1 = "\"\""
        if args_id >= 0
          a = get_args(args_id)
          if a.length >= 2
            arg1 = compile_expr(a[1])
          end
        end
        return "sp_str_sub(" + rc + ", " + compile_arg0(nid) + ", " + arg1 + ")"
      end
      if mname == "capitalize"
        return "sp_str_capitalize(" + rc + ")"
      end
      if mname == "count"
        return "sp_str_count(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "*"
        return "sp_str_repeat(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "empty?"
        return "(strlen(" + rc + ") == 0)"
      end
      if mname == "chars"
        @needs_str_array = 1
        @needs_gc = 1
        return "sp_str_split(" + rc + ", \"\")"
      end
      if mname == "bytes"
        @needs_int_array = 1
        @needs_gc = 1
        return "sp_str_bytes(" + rc + ")"
      end
      if mname == "hex"
        return "((mrb_int)strtoll(" + rc + ", NULL, 16))"
      end
      if mname == "oct"
        return "((mrb_int)strtoll(" + rc + ", NULL, 8))"
      end
      if mname == "tr"
        args_id = @nd_arguments[nid]
        arg1 = "\"\""
        if args_id >= 0
          a = get_args(args_id)
          if a.length >= 2
            arg1 = compile_expr(a[1])
          end
        end
        return "sp_str_tr(" + rc + ", " + compile_arg0(nid) + ", " + arg1 + ")"
      end
      if mname == "delete"
        return "sp_str_delete(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "squeeze"
        return "sp_str_squeeze(" + rc + ")"
      end
      if mname == "size"
        return "(mrb_int)strlen(" + rc + ")"
      end
      if mname == "slice"
        args_id = @nd_arguments[nid]
        if args_id >= 0
          a = get_args(args_id)
          if a.length >= 2
            return "sp_str_sub_range(" + rc + ", " + compile_expr(a[0]) + ", " + compile_expr(a[1]) + ")"
          end
        end
        return "sp_str_sub_range(" + rc + ", " + compile_arg0(nid) + ", 1)"
      end
      if mname == "ljust"
        args_id = @nd_arguments[nid]
        if args_id >= 0
          a = get_args(args_id)
          if a.length >= 2
            return "sp_str_ljust2(" + rc + ", " + compile_expr(a[0]) + ", " + compile_expr(a[1]) + ")"
          end
        end
        return "sp_str_ljust(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "rjust"
        args_id = @nd_arguments[nid]
        if args_id >= 0
          a = get_args(args_id)
          if a.length >= 2
            return "sp_str_rjust2(" + rc + ", " + compile_expr(a[0]) + ", " + compile_expr(a[1]) + ")"
          end
        end
        return "sp_str_rjust(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "center"
        return "sp_str_center(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "lstrip"
        return "sp_str_lstrip(" + rc + ")"
      end
      if mname == "rstrip"
        return "sp_str_rstrip(" + rc + ")"
      end
      if mname == "dup"
        return "sp_str_dup(" + rc + ")"
      end
      if mname == "to_s"
        return rc
      end
    end

    # Range methods
    if recv_type == "range"
      if mname == "first"
        return rc + ".first"
      end
      if mname == "last"
        return rc + ".last"
      end
      if mname == "include?"
        tmp = new_temp
        emit("  sp_Range " + tmp + " = " + rc + ";")
        return "(" + compile_arg0(nid) + " >= " + tmp + ".first && " + compile_arg0(nid) + " <= " + tmp + ".last)"
      end
      if mname == "to_a"
        @needs_int_array = 1
        @needs_gc = 1
        return "sp_IntArray_from_range(" + rc + ".first, " + rc + ".last)"
      end
      if mname == "length"
        return "(" + rc + ".last - " + rc + ".first + 1)"
      end
      if mname == "size"
        return "(" + rc + ".last - " + rc + ".first + 1)"
      end
    end

    # Integer methods
    if recv_type == "int"
      if mname == "to_s"
        @needs_string_helpers = 1
        return "sp_int_to_s(" + rc + ")"
      end
      if mname == "to_i"
        return rc
      end
      if mname == "to_f"
        return "(mrb_float)(" + rc + ")"
      end
      if mname == "abs"
        return "((" + rc + ") < 0 ? -(" + rc + ") : (" + rc + "))"
      end
      if mname == "even?"
        return "((" + rc + ") % 2 == 0)"
      end
      if mname == "odd?"
        return "((" + rc + ") % 2 != 0)"
      end
      if mname == "zero?"
        return "((" + rc + ") == 0)"
      end
      if mname == "gcd"
        return "sp_gcd(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "clamp"
        args_id = @nd_arguments[nid]
        if args_id >= 0
          a = get_args(args_id)
          if a.length >= 2
            return "sp_clamp(" + rc + ", " + compile_expr(a[0]) + ", " + compile_expr(a[1]) + ")"
          end
        end
      end
      if mname == "frozen?"
        return "TRUE"
      end
      if mname == "chr"
        @needs_string_helpers = 1
        return "sp_int_chr(" + rc + ")"
      end
    end

    if recv_type == "float"
      if mname == "to_s"
        @needs_string_helpers = 1
        return "sp_float_to_s(" + rc + ")"
      end
      if mname == "to_i"
        return "(mrb_int)(" + rc + ")"
      end
      if mname == "ceil"
        return "(mrb_int)ceil(" + rc + ")"
      end
      if mname == "floor"
        return "(mrb_int)floor(" + rc + ")"
      end
      if mname == "round"
        return "(mrb_int)round(" + rc + ")"
      end
      if mname == "abs"
        return "fabs(" + rc + ")"
      end
    end

    if recv_type == "bool"
      if mname == "to_s"
        return "(" + rc + " ? \"true\" : \"false\")"
      end
    end

    # Array methods
    if recv_type == "int_array"
      if mname == "length"
        return "sp_IntArray_length(" + rc + ")"
      end
      if mname == "[]"
        return "sp_IntArray_get(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "push"
        return "(sp_IntArray_push(" + rc + ", " + compile_arg0(nid) + "), 0)"
      end
      if mname == "pop"
        return "sp_IntArray_pop(" + rc + ")"
      end
      if mname == "empty?"
        return "sp_IntArray_empty(" + rc + ")"
      end
      if mname == "include?"
        return "sp_IntArray_include(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "sort"
        return "sp_IntArray_sort(" + rc + ")"
      end
      if mname == "first"
        return "sp_IntArray_get(" + rc + ", 0)"
      end
      if mname == "last"
        return "sp_IntArray_get(" + rc + ", sp_IntArray_length(" + rc + ") - 1)"
      end
      if mname == "min"
        return "sp_IntArray_min(" + rc + ")"
      end
      if mname == "max"
        return "sp_IntArray_max(" + rc + ")"
      end
      if mname == "sum"
        return "sp_IntArray_sum(" + rc + ")"
      end
      if mname == "to_a"
        return "sp_IntArray_dup(" + rc + ")"
      end
      if mname == "uniq"
        return "sp_IntArray_uniq(" + rc + ")"
      end
      if mname == "join"
        @needs_string_helpers = 1
        return "sp_IntArray_join(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "reverse"
        return "({ sp_IntArray *_r = sp_IntArray_dup(" + rc + "); sp_IntArray_reverse_bang(_r); _r; })"
      end
    end
    if recv_type == "str_array"
      if mname == "length"
        return "sp_StrArray_length(" + rc + ")"
      end
      if mname == "[]"
        return "sp_StrArray_get(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "first"
        return "sp_StrArray_get(" + rc + ", 0)"
      end
      if mname == "last"
        return "sp_StrArray_get(" + rc + ", sp_StrArray_length(" + rc + ") - 1)"
      end
      if mname == "join"
        @needs_string_helpers = 1
        return "sp_StrArray_join(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "push"
        return "(sp_StrArray_push(" + rc + ", " + compile_arg0(nid) + "), 0)"
      end
      if mname == "pop"
        return "sp_StrArray_pop(" + rc + ")"
      end
      if mname == "empty?"
        return "sp_StrArray_empty(" + rc + ")"
      end
      if mname == "include?"
        return "sp_StrArray_include(" + rc + ", " + compile_arg0(nid) + ")"
      end
    end

    # Hash methods
    if recv_type == "str_int_hash"
      if mname == "[]"
        return "sp_StrIntHash_get(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "has_key?"
        return "sp_StrIntHash_has_key(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "length"
        return "sp_StrIntHash_length(" + rc + ")"
      end
      if mname == "keys"
        return "sp_StrIntHash_keys(" + rc + ")"
      end
    end
    if recv_type == "str_str_hash"
      if mname == "[]"
        return "sp_StrStrHash_get(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "has_key?"
        return "sp_StrStrHash_has_key(" + rc + ", " + compile_arg0(nid) + ")"
      end
      if mname == "length"
        return "sp_StrStrHash_length(" + rc + ")"
      end
      if mname == "keys"
        return "sp_StrStrHash_keys(" + rc + ")"
      end
    end

    # map as expression
    if mname == "map"
      if @nd_block[nid] >= 0
        return compile_map_expr(nid)
      end
    end

    # select as expression
    if mname == "select"
      if @nd_block[nid] >= 0
        return compile_select_expr(nid)
      end
    end

    # reject as expression
    if mname == "reject"
      if @nd_block[nid] >= 0
        return compile_reject_expr(nid)
      end
    end

    # reduce/inject as expression
    if mname == "reduce"
      if @nd_block[nid] >= 0
        return compile_reduce_expr(nid)
      end
    end
    if mname == "inject"
      if @nd_block[nid] >= 0
        return compile_reduce_expr(nid)
      end
    end

    # ARGV methods
    if @nd_type[recv] == "ConstantReadNode"
      if @nd_name[recv] == "ARGV"
        if mname == "length"
          return "sp_argv.len"
        end
        if mname == "[]"
          return "sp_argv.data[(int)" + compile_arg0(nid) + "]"
        end
      end
    end

    # Math
    if @nd_type[recv] == "ConstantReadNode"
      rcname = @nd_name[recv]
      if rcname == "Math"
        if mname == "sqrt"
          return "sqrt(" + compile_arg0(nid) + ")"
        end
      end
      # File operations
      if rcname == "File"
        if mname == "read"
          @needs_file_io = 1
          return "sp_file_read(" + compile_arg0(nid) + ")"
        end
        if mname == "exist?"
          @needs_file_io = 1
          return "sp_file_exist(" + compile_arg0(nid) + ")"
        end
        if mname == "delete"
          @needs_file_io = 1
          return "(sp_file_delete(" + compile_arg0(nid) + "), 0)"
        end
        if mname == "join"
          @needs_string_helpers = 1
          args_id = @nd_arguments[nid]
          if args_id >= 0
            arg_ids = get_args(args_id)
            if arg_ids.length >= 2
              return "sp_str_concat(sp_str_concat(" + compile_expr(arg_ids[0]) + ", \"/\"), " + compile_expr(arg_ids[1]) + ")"
            end
          end
          return "\"\""
        end
        if mname == "basename"
          @needs_string_helpers = 1
          return "sp_file_basename(" + compile_arg0(nid) + ")"
        end
      end
      # Time
      if rcname == "Time"
        if mname == "now"
          return "((mrb_int)time(NULL))"
        end
      end
      # ENV
      if rcname == "ENV"
        if mname == "[]"
          return "getenv(" + compile_arg0(nid) + ")"
        end
      end
      # Dir
      if rcname == "Dir"
        if mname == "home"
          return "getenv(\"HOME\")"
        end
      end
    end

    # to_a on range (including parenthesized range)
    if mname == "to_a"
      range_nid = -1
      if @nd_type[recv] == "RangeNode"
        range_nid = recv
      end
      if @nd_type[recv] == "ParenthesesNode"
        pb = @nd_body[recv]
        if pb >= 0
          pstmts = get_stmts(pb)
          if pstmts.length > 0
            if @nd_type[pstmts[0]] == "RangeNode"
              range_nid = pstmts[0]
            end
          end
        end
      end
      if range_nid >= 0
        @needs_int_array = 1
        @needs_gc = 1
        return "sp_IntArray_from_range(" + compile_expr(@nd_left[range_nid]) + ", " + compile_expr(@nd_right[range_nid]) + ")"
      end
    end

    # Poly method calls
    if recv_type == "poly"
      return compile_poly_method_call(nid, rc, mname)
    end

    # is_a? - check class hierarchy
    if mname == "is_a?"
      if is_obj_type(recv_type) == 1
        cname = recv_type[4, recv_type.length - 4]
        arg0 = ""
        args_id = @nd_arguments[nid]
        if args_id >= 0
          a = get_args(args_id)
          if a.length > 0
            arg0 = @nd_name[a[0]]
          end
        end
        # Check if cname is or inherits from arg0
        if is_class_or_ancestor(cname, arg0) == 1
          return "TRUE"
        else
          return "FALSE"
        end
      end
      return "FALSE"
    end

    # respond_to? - check if method exists
    if mname == "respond_to?"
      if is_obj_type(recv_type) == 1
        cname = recv_type[4, recv_type.length - 4]
        ci = find_class_idx(cname)
        if ci >= 0
          arg0 = ""
          args_id = @nd_arguments[nid]
          if args_id >= 0
            a = get_args(args_id)
            if a.length > 0
              arg0 = @nd_content[a[0]]
            end
          end
          if cls_find_method(ci, arg0) >= 0
            return "TRUE"
          end
          # Check attr_readers
          readers = @cls_attr_readers[ci].split(";")
          rk = 0
          while rk < readers.length
            if readers[rk] == arg0
              return "TRUE"
            end
            rk = rk + 1
          end
          return "FALSE"
        end
      end
      return "FALSE"
    end

    # nil?
    if mname == "nil?"
      if recv_type == "nil"
        return "TRUE"
      end
      if recv_type == "poly"
        return "sp_poly_nil_p(" + rc + ")"
      end
      if type_is_pointer(recv_type) == 1
        return "(" + rc + " == NULL)"
      end
      return "FALSE"
    end

    # frozen? on any type
    if mname == "frozen?"
      return "TRUE"
    end

    # positive? / negative?
    if mname == "positive?"
      return "(" + rc + " > 0)"
    end
    if mname == "negative?"
      return "(" + rc + " < 0)"
    end

    # Object method calls
    if is_obj_type(recv_type) == 1
      cname = recv_type[4, recv_type.length - 4]
      ci = find_class_idx(cname)
      if ci >= 0
        # attr_reader
        readers = @cls_attr_readers[ci].split(";")
        j = 0
        while j < readers.length
          if readers[j] == mname
            return rc + "->" + mname
          end
          j = j + 1
        end
        # attr_writer
        if mname.length > 1
          if mname[mname.length - 1] == "="
            bname = mname[0, mname.length - 1]
            writers = @cls_attr_writers[ci].split(";")
            j = 0
            while j < writers.length
              if writers[j] == bname
                return "(" + rc + "->" + bname + " = " + compile_arg0(nid) + ")"
              end
              j = j + 1
            end
          end
        end
        # Method call
        owner = find_method_owner(ci, mname)
        if owner != ""
          ca = compile_call_args(nid)
          if owner == cname
            if ca != ""
              return "sp_" + owner + "_" + sanitize_name(mname) + "(" + rc + ", " + ca + ")"
            else
              return "sp_" + owner + "_" + sanitize_name(mname) + "(" + rc + ")"
            end
          else
            if ca != ""
              return "sp_" + owner + "_" + sanitize_name(mname) + "((sp_" + owner + " *)" + rc + ", " + ca + ")"
            else
              return "sp_" + owner + "_" + sanitize_name(mname) + "((sp_" + owner + " *)" + rc + ")"
            end
          end
        end
      end
    end

    "0"
  end

  def compile_poly_method_call(nid, rc, mname)
    @needs_rb_value = 1
    if mname == "nil?"
      return "sp_poly_nil_p(" + rc + ")"
    end
    if mname == "to_s"
      return "sp_poly_to_s(" + rc + ")"
    end
    # For object method calls, dispatch based on cls_id
    # Generate: switch on v.tag and cls_id
    tmp = new_temp
    emit("  const char *" + tmp + " = \"\";")
    emit("  if (" + rc + ".tag == SP_TAG_OBJ) {")
    # Dispatch to each possible class
    i = 0
    while i < @cls_names.length
      cname = @cls_names[i]
      mi = cls_find_method(@cls_names.length - 1 - i, mname)
      # Check if this class has the method
      midx = cls_find_method_direct(i, mname)
      if midx >= 0
        emit("    if (" + rc + ".v.cls_id == " + i.to_s + ") " + tmp + " = sp_" + cname + "_" + sanitize_name(mname) + "((sp_" + cname + " *)" + rc + ".v.p);")
      end
      i = i + 1
    end
    emit("  }")
    tmp
  end

  def compile_eq(nid, op)
    recv = @nd_receiver[nid]
    lt = infer_type(recv)
    args_id = @nd_arguments[nid]
    arg_id = -1
    if args_id >= 0
      a = get_args(args_id)
      if a.length > 0
        arg_id = a[0]
      end
    end
    at = "int"
    if arg_id >= 0
      at = infer_type(arg_id)
    end
    lc = compile_expr(recv)
    rc = "0"
    if arg_id >= 0
      rc = compile_expr(arg_id)
    end
    if lt == "string"
      if at == "nil"
        if op == "=="
          return "(" + lc + " == NULL)"
        else
          return "(" + lc + " != NULL)"
        end
      end
      if op == "=="
        return "(strcmp(" + lc + ", " + rc + ") == 0)"
      else
        return "(strcmp(" + lc + ", " + rc + ") != 0)"
      end
    end
    if at == "nil"
      if type_is_pointer(lt) == 1
        if op == "=="
          return "(" + lc + " == NULL)"
        else
          return "(" + lc + " != NULL)"
        end
      end
    end
    "(" + lc + " " + op + " " + rc + ")"
  end

  def box_expr_to_poly(nid)
    at = infer_type(nid)
    val = compile_expr(nid)
    if at == "poly"
      return val
    end
    if at == "int"
      return "sp_box_int(" + val + ")"
    end
    if at == "string"
      return "sp_box_str(" + val + ")"
    end
    if at == "float"
      return "sp_box_float(" + val + ")"
    end
    if at == "bool"
      return "sp_box_bool(" + val + ")"
    end
    if at == "nil"
      return "sp_box_nil()"
    end
    if is_obj_type(at) == 1
      cname = at[4, at.length - 4]
      ci = find_class_idx(cname)
      return "sp_box_obj(" + val + ", " + ci.to_s + ")"
    end
    "sp_box_int(" + val + ")"
  end

  def compile_call_args_with_defaults(nid, mi)
    args_id = @nd_arguments[nid]
    arg_ids = []
    if args_id >= 0
      arg_ids = get_args(args_id)
    end
    pnames = @meth_param_names[mi].split(",")
    ptypes = @meth_param_types[mi].split(",")
    defaults = @meth_has_defaults[mi].split(",")

    # Check if args contain a KeywordHashNode - extract kw pairs
    kw_names = "".split(",")
    kw_vals = "".split(",")
    positional_ids = []
    is_splat_call = 0
    ak = 0
    while ak < arg_ids.length
      if @nd_type[arg_ids[ak]] == "KeywordHashNode"
        elems = parse_id_list(@nd_elements[arg_ids[ak]])
        ek = 0
        while ek < elems.length
          if @nd_type[elems[ek]] == "AssocNode"
            key_id = @nd_key[elems[ek]]
            if key_id >= 0
              kname = ""
              if @nd_type[key_id] == "SymbolNode"
                kname = @nd_content[key_id]
              end
              kw_names.push(kname)
              kw_vals.push(compile_expr(@nd_expression[elems[ek]]))
            end
          end
          ek = ek + 1
        end
      else
        positional_ids.push(arg_ids[ak])
      end
      ak = ak + 1
    end

    result = ""
    k = 0
    while k < pnames.length
      if k > 0
        result = result + ", "
      end
      # Check keyword args first
      kw_found = 0
      ki = 0
      while ki < kw_names.length
        if kw_names[ki] == pnames[k]
          kw_found = 1
          # Check if param is poly
          if k < ptypes.length
            if ptypes[k] == "poly"
              # Need to box - kw_vals[ki] is already compiled
              at_guess = "string"
              result = result + "sp_box_str(" + kw_vals[ki] + ")"
            else
              result = result + kw_vals[ki]
            end
          else
            result = result + kw_vals[ki]
          end
        end
        ki = ki + 1
      end
      if kw_found == 0
        if k < ptypes.length
          if ptypes[k] == "int_array"
            # Only splat if there are more positional args than remaining params
            # (i.e., this is a rest/splat parameter, not a regular array param)
            if positional_ids.length > (pnames.length - k)
              @needs_int_array = 1
              @needs_gc = 1
              tmp = new_temp
              emit("  sp_IntArray *" + tmp + " = sp_IntArray_new();")
              pi = 0
              while pi < positional_ids.length
                emit("  sp_IntArray_push(" + tmp + ", " + compile_expr(positional_ids[pi]) + ");")
                pi = pi + 1
              end
              result = result + tmp
              k = k + 1
              next
            end
          end
        end
        if k < positional_ids.length
          if k < ptypes.length
            if ptypes[k] == "poly"
              result = result + box_expr_to_poly(positional_ids[k])
              k = k + 1
              next
            end
          end
          result = result + compile_expr(positional_ids[k])
        else
          # Use default value
          if k < defaults.length
            def_id = defaults[k].to_i
            if def_id >= 0
              result = result + compile_expr(def_id)
            else
              result = result + "0"
            end
          else
            result = result + "0"
          end
        end
      end
      k = k + 1
    end
    result
  end

  def compile_constructor_args(ci, nid)
    args_id = @nd_arguments[nid]
    if args_id < 0
      return ""
    end
    arg_ids = get_args(args_id)
    # Check if any arg is a KeywordHashNode
    has_kw = 0
    ak = 0
    while ak < arg_ids.length
      if @nd_type[arg_ids[ak]] == "KeywordHashNode"
        has_kw = 1
      end
      ak = ak + 1
    end
    if has_kw == 0
      return compile_call_args(nid)
    end
    # Extract keyword pairs
    kw_names = "".split(",")
    kw_vals = "".split(",")
    ak = 0
    while ak < arg_ids.length
      if @nd_type[arg_ids[ak]] == "KeywordHashNode"
        elems = parse_id_list(@nd_elements[arg_ids[ak]])
        ek = 0
        while ek < elems.length
          if @nd_type[elems[ek]] == "AssocNode"
            key_id = @nd_key[elems[ek]]
            if key_id >= 0
              kname = ""
              if @nd_type[key_id] == "SymbolNode"
                kname = @nd_content[key_id]
              end
              kw_names.push(kname)
              kw_vals.push(compile_expr(@nd_expression[elems[ek]]))
            end
          end
          ek = ek + 1
        end
      end
      ak = ak + 1
    end
    # Get init param names from class
    init_ci = find_init_class(ci)
    if init_ci < 0
      return compile_call_args(nid)
    end
    init_idx = cls_find_method_direct(init_ci, "initialize")
    if init_idx < 0
      return compile_call_args(nid)
    end
    all_params = @cls_meth_params[init_ci].split("|")
    pnames = []
    if init_idx < all_params.length
      pnames = all_params[init_idx].split(",")
    end
    # Build args in param order using keyword values
    result = ""
    pk = 0
    while pk < pnames.length
      if pk > 0
        result = result + ", "
      end
      found = 0
      ki = 0
      while ki < kw_names.length
        if kw_names[ki] == pnames[pk]
          result = result + kw_vals[ki]
          found = 1
        end
        ki = ki + 1
      end
      if found == 0
        result = result + "0"
      end
      pk = pk + 1
    end
    result
  end

  def compile_call_args(nid)
    args_id = @nd_arguments[nid]
    if args_id < 0
      return ""
    end
    arg_ids = get_args(args_id)
    result = ""
    k = 0
    while k < arg_ids.length
      if k > 0
        result = result + ", "
      end
      result = result + compile_expr(arg_ids[k])
      k = k + 1
    end
    result
  end

  def find_method_owner(ci, mname)
    if ci < 0
      return ""
    end
    mnames = @cls_meth_names[ci].split(";")
    j = 0
    while j < mnames.length
      if mnames[j] == mname
        return @cls_names[ci]
      end
      j = j + 1
    end
    if @cls_parents[ci] != ""
      pi = find_class_idx(@cls_parents[ci])
      if pi >= 0
        return find_method_owner(pi, mname)
      end
    end
    ""
  end

  def compile_if_expr(nid)
    cond = compile_expr(@nd_predicate[nid])
    then_val = "0"
    body = @nd_body[nid]
    if body >= 0
      stmts = get_stmts(body)
      if stmts.length > 0
        then_val = compile_expr(stmts[stmts.length - 1])
      end
    end
    else_val = "0"
    sub = @nd_subsequent[nid]
    if sub >= 0
      if @nd_type[sub] == "ElseNode"
        eb = @nd_body[sub]
        if eb >= 0
          es = get_stmts(eb)
          if es.length > 0
            else_val = compile_expr(es[es.length - 1])
          end
        end
      else
        else_val = compile_if_expr(sub)
      end
    end
    "(" + cond + " ? " + then_val + " : " + else_val + ")"
  end

  def compile_unless_expr(nid)
    cond = compile_expr(@nd_predicate[nid])
    then_val = "0"
    body = @nd_body[nid]
    if body >= 0
      stmts = get_stmts(body)
      if stmts.length > 0
        then_val = compile_expr(stmts[stmts.length - 1])
      end
    end
    "(!" + cond + " ? " + then_val + " : 0)"
  end

  def compile_array_literal(nid)
    @needs_gc = 1
    elems = parse_id_list(@nd_elements[nid])
    if elems.length == 0
      @needs_int_array = 1
      return "sp_IntArray_new()"
    end
    et = infer_type(elems[0])
    if et == "string"
      @needs_str_array = 1
      tmp = new_temp
      emit("  sp_StrArray *" + tmp + " = sp_StrArray_new();")
      k = 0
      while k < elems.length
        emit("  sp_StrArray_push(" + tmp + ", " + compile_expr(elems[k]) + ");")
        k = k + 1
      end
      return tmp
    end
    @needs_int_array = 1
    tmp = new_temp
    emit("  sp_IntArray *" + tmp + " = sp_IntArray_new();")
    k = 0
    while k < elems.length
      emit("  sp_IntArray_push(" + tmp + ", " + compile_expr(elems[k]) + ");")
      k = k + 1
    end
    tmp
  end

  def compile_hash_literal(nid)
    @needs_gc = 1
    elems = parse_id_list(@nd_elements[nid])
    if elems.length == 0
      @needs_str_int_hash = 1
      return "sp_StrIntHash_new()"
    end
    vtype = "int"
    eid = elems[0]
    if @nd_type[eid] == "AssocNode"
      vtype = infer_type(@nd_expression[eid])
    end
    if vtype == "string"
      @needs_str_str_hash = 1
      tmp = new_temp
      emit("  sp_StrStrHash *" + tmp + " = sp_StrStrHash_new();")
      k = 0
      while k < elems.length
        el = elems[k]
        if @nd_type[el] == "AssocNode"
          emit("  sp_StrStrHash_set(" + tmp + ", " + compile_expr(@nd_key[el]) + ", " + compile_expr(@nd_expression[el]) + ");")
        end
        k = k + 1
      end
      return tmp
    end
    @needs_str_int_hash = 1
    tmp = new_temp
    emit("  sp_StrIntHash *" + tmp + " = sp_StrIntHash_new();")
    k = 0
    while k < elems.length
      el = elems[k]
      if @nd_type[el] == "AssocNode"
        emit("  sp_StrIntHash_set(" + tmp + ", " + compile_expr(@nd_key[el]) + ", " + compile_expr(@nd_expression[el]) + ");")
      end
      k = k + 1
    end
    tmp
  end

  # ---- Statement compiler ----
  def compile_stmt(nid)
    if nid < 0
      return
    end
    t = @nd_type[nid]
    if t == "MultiWriteNode"
      compile_multi_write(nid)
      return
    end
    if t == "LocalVariableWriteNode"
      lname = @nd_name[nid]
      vt = find_var_type(lname)
      if vt == "poly"
        # Box the value
        emit("  lv_" + lname + " = " + box_expr_to_poly(@nd_expression[nid]) + ";")
        return
      end
      val = compile_expr(@nd_expression[nid])
      emit("  lv_" + lname + " = " + val + ";")
      set_var_type(lname, infer_type(@nd_expression[nid]))
      return
    end
    if t == "LocalVariableOperatorWriteNode"
      op = @nd_binop[nid]
      val = compile_expr(@nd_expression[nid])
      if op == "+"
        emit("  lv_" + @nd_name[nid] + " += " + val + ";")
      end
      if op == "-"
        emit("  lv_" + @nd_name[nid] + " -= " + val + ";")
      end
      if op == "*"
        emit("  lv_" + @nd_name[nid] + " *= " + val + ";")
      end
      if op == "/"
        emit("  lv_" + @nd_name[nid] + " /= " + val + ";")
      end
      if op == "%"
        emit("  lv_" + @nd_name[nid] + " = sp_imod(lv_" + @nd_name[nid] + ", " + val + ");")
      end
      return
    end
    if t == "InstanceVariableWriteNode"
      val = compile_expr(@nd_expression[nid])
      emit("  self->" + sanitize_ivar(@nd_name[nid]) + " = " + val + ";")
      return
    end
    if t == "InstanceVariableOperatorWriteNode"
      op = @nd_binop[nid]
      val = compile_expr(@nd_expression[nid])
      ivar = sanitize_ivar(@nd_name[nid])
      if op == "+"
        emit("  self->" + ivar + " += " + val + ";")
      end
      if op == "-"
        emit("  self->" + ivar + " -= " + val + ";")
      end
      return
    end
    if t == "IfNode"
      compile_if_stmt(nid)
      return
    end
    if t == "UnlessNode"
      compile_unless_stmt(nid)
      return
    end
    if t == "WhileNode"
      compile_while_stmt(nid)
      return
    end
    if t == "UntilNode"
      compile_until_stmt(nid)
      return
    end
    if t == "ForNode"
      compile_for_stmt(nid)
      return
    end
    if t == "CaseNode"
      compile_case_stmt(nid)
      return
    end
    if t == "CaseMatchNode"
      compile_case_match_stmt(nid)
      return
    end
    if t == "ReturnNode"
      compile_return_stmt(nid)
      return
    end
    if t == "BreakNode"
      emit("  break;")
      return
    end
    if t == "NextNode"
      emit("  continue;")
      return
    end
    if t == "RetryNode"
      emit("  continue;")
      return
    end
    if t == "YieldNode"
      compile_yield_stmt(nid)
      return
    end
    if t == "BeginNode"
      compile_begin_stmt(nid)
      return
    end
    if t == "CallNode"
      compile_call_stmt(nid)
      return
    end
    if t == "StatementsNode"
      stmts = parse_id_list(@nd_stmts[nid])
      k = 0
      while k < stmts.length
        compile_stmt(stmts[k])
        k = k + 1
      end
      return
    end
    expr = compile_expr(nid)
    if expr != "0"
      emit("  " + expr + ";")
    end
    return
  end

  def compile_multi_write(nid)
    targets = parse_id_list(@nd_targets[nid])
    val_id = @nd_expression[nid]
    if val_id < 0
      return
    end
    if @nd_type[val_id] == "ArrayNode"
      # Direct array literal: a, b, c = [1, 2, 3] or a, b = b, a
      elems = parse_id_list(@nd_elements[val_id])
      # For swap safety, evaluate all RHS first into temps
      tmps = "".split(",")
      k = 0
      while k < elems.length
        tmp = new_temp
        tmps.push(tmp)
        emit("  mrb_int " + tmp + " = " + compile_expr(elems[k]) + ";")
        k = k + 1
      end
      # Now assign
      k = 0
      while k < targets.length
        if k < tmps.length
          tid = targets[k]
          if @nd_type[tid] == "LocalVariableTargetNode"
            emit("  lv_" + @nd_name[tid] + " = " + tmps[k] + ";")
          end
        end
        k = k + 1
      end
    else
      # RHS is a function call returning int_array
      @needs_int_array = 1
      @needs_gc = 1
      tmp = new_temp
      emit("  sp_IntArray *" + tmp + " = " + compile_expr(val_id) + ";")
      emit("  SP_GC_ROOT(" + tmp + ");")
      k = 0
      while k < targets.length
        tid = targets[k]
        if @nd_type[tid] == "LocalVariableTargetNode"
          emit("  lv_" + @nd_name[tid] + " = sp_IntArray_get(" + tmp + ", " + k.to_s + ");")
        end
        k = k + 1
      end
    end
  end

  def compile_if_stmt(nid)
    cond = compile_expr(@nd_predicate[nid])
    emit("  if (" + cond + ") {")
    @indent = @indent + 1
    compile_stmts_body(@nd_body[nid])
    @indent = @indent - 1
    sub = @nd_subsequent[nid]
    if sub >= 0
      if @nd_type[sub] == "ElseNode"
        emit("  } else {")
        @indent = @indent + 1
        compile_stmts_body(@nd_body[sub])
        @indent = @indent - 1
      else
        emit("  } else")
        compile_if_stmt(sub)
        return
      end
    end
    emit("  }")
  end

  def compile_unless_stmt(nid)
    cond = compile_expr(@nd_predicate[nid])
    emit("  if (!(" + cond + ")) {")
    @indent = @indent + 1
    compile_stmts_body(@nd_body[nid])
    @indent = @indent - 1
    ec = @nd_else_clause[nid]
    if ec >= 0
      emit("  } else {")
      @indent = @indent + 1
      compile_stmts_body(@nd_body[ec])
      @indent = @indent - 1
    end
    emit("  }")
  end

  def compile_while_stmt(nid)
    old = @in_loop
    @in_loop = 1
    cond = compile_expr(@nd_predicate[nid])
    emit("  while (" + cond + ") {")
    @indent = @indent + 1
    compile_stmts_body(@nd_body[nid])
    @indent = @indent - 1
    emit("  }")
    @in_loop = old
  end

  def compile_until_stmt(nid)
    old = @in_loop
    @in_loop = 1
    cond = compile_expr(@nd_predicate[nid])
    emit("  while (!(" + cond + ")) {")
    @indent = @indent + 1
    compile_stmts_body(@nd_body[nid])
    @indent = @indent - 1
    emit("  }")
    @in_loop = old
  end

  def compile_for_stmt(nid)
    old = @in_loop
    @in_loop = 1
    coll = @nd_collection[nid]
    if coll >= 0
      if @nd_type[coll] == "RangeNode"
        vname = "i"
        tgt = @nd_target[nid]
        if tgt >= 0
          if @nd_type[tgt] == "LocalVariableTargetNode"
            vname = @nd_name[tgt]
          end
        end
        left = compile_expr(@nd_left[coll])
        right = compile_expr(@nd_right[coll])
        emit("  for (lv_" + vname + " = " + left + "; lv_" + vname + " <= " + right + "; lv_" + vname + "++) {")
        @indent = @indent + 1
        compile_stmts_body(@nd_body[nid])
        @indent = @indent - 1
        emit("  }")
      end
    end
    @in_loop = old
  end

  def compile_case_stmt(nid)
    pred = @nd_predicate[nid]
    if pred < 0
      compile_case_no_pred(nid)
      return
    end
    pred_type = infer_type(pred)
    pred_val = compile_expr(pred)
    tmp = new_temp
    if pred_type == "string"
      emit("  const char *" + tmp + " = " + pred_val + ";")
    else
      emit("  mrb_int " + tmp + " = " + pred_val + ";")
    end
    conds = parse_id_list(@nd_conditions[nid])
    k = 0
    while k < conds.length
      wid = conds[k]
      if @nd_type[wid] == "WhenNode"
        kw = "if"
        if k > 0
          kw = "} else if"
        end
        cond_str = compile_when_conds(wid, tmp, pred_type)
        emit("  " + kw + " (" + cond_str + ") {")
        @indent = @indent + 1
        compile_stmts_body(@nd_body[wid])
        @indent = @indent - 1
      end
      k = k + 1
    end
    ec = @nd_else_clause[nid]
    if ec >= 0
      emit("  } else {")
      @indent = @indent + 1
      compile_stmts_body(@nd_body[ec])
      @indent = @indent - 1
    end
    emit("  }")
  end

  def compile_case_no_pred(nid)
    conds = parse_id_list(@nd_conditions[nid])
    k = 0
    while k < conds.length
      wid = conds[k]
      if @nd_type[wid] == "WhenNode"
        kw = "if"
        if k > 0
          kw = "} else if"
        end
        wconds = parse_id_list(@nd_conditions[wid])
        cexpr = "0"
        if wconds.length > 0
          cexpr = compile_expr(wconds[0])
        end
        emit("  " + kw + " (" + cexpr + ") {")
        @indent = @indent + 1
        compile_stmts_body(@nd_body[wid])
        @indent = @indent - 1
      end
      k = k + 1
    end
    ec = @nd_else_clause[nid]
    if ec >= 0
      emit("  } else {")
      @indent = @indent + 1
      compile_stmts_body(@nd_body[ec])
      @indent = @indent - 1
    end
    emit("  }")
  end

  def compile_when_conds(wid, tmp, pred_type)
    wconds = parse_id_list(@nd_conditions[wid])
    result = ""
    k = 0
    while k < wconds.length
      if k > 0
        result = result + " || "
      end
      cid = wconds[k]
      if @nd_type[cid] == "RangeNode"
        left = compile_expr(@nd_left[cid])
        right = compile_expr(@nd_right[cid])
        result = result + "(" + tmp + " >= " + left + " && " + tmp + " <= " + right + ")"
      else
        if pred_type == "string"
          result = result + "strcmp(" + tmp + ", " + compile_expr(cid) + ") == 0"
        else
          result = result + tmp + " == " + compile_expr(cid)
        end
      end
      k = k + 1
    end
    result
  end

  def compile_case_match_stmt(nid)
    pred = @nd_predicate[nid]
    pred_type = infer_type(pred)
    pred_val = compile_expr(pred)
    tmp = new_temp
    if pred_type == "poly"
      emit("  sp_RbVal " + tmp + " = " + pred_val + ";")
    else
      if pred_type == "string"
        emit("  const char *" + tmp + " = " + pred_val + ";")
      else
        if pred_type == "float"
          emit("  mrb_float " + tmp + " = " + pred_val + ";")
        else
          emit("  mrb_int " + tmp + " = " + pred_val + ";")
        end
      end
    end
    conds = parse_id_list(@nd_conditions[nid])
    k = 0
    while k < conds.length
      inid = conds[k]
      if @nd_type[inid] == "InNode"
        kw = "if"
        if k > 0
          kw = "} else if"
        end
        pat = @nd_pattern[inid]
        cond_str = compile_in_pattern(pat, tmp, pred_type)
        emit("  " + kw + " (" + cond_str + ") {")
        @indent = @indent + 1
        compile_stmts_body(@nd_body[inid])
        @indent = @indent - 1
      end
      k = k + 1
    end
    ec = @nd_else_clause[nid]
    if ec >= 0
      emit("  } else {")
      @indent = @indent + 1
      compile_stmts_body(@nd_body[ec])
      @indent = @indent - 1
    end
    if conds.length > 0
      emit("  }")
    end
  end

  def compile_in_pattern(pat_id, tmp, pred_type)
    if pat_id < 0
      return "1"
    end
    pt = @nd_type[pat_id]
    if pt == "ConstantReadNode"
      cname = @nd_name[pat_id]
      if pred_type == "poly"
        if cname == "Integer"
          return tmp + ".tag == SP_TAG_INT"
        end
        if cname == "String"
          return tmp + ".tag == SP_TAG_STR"
        end
        if cname == "Float"
          return tmp + ".tag == SP_TAG_FLT"
        end
        return "0"
      end
      if cname == "Integer"
        return "1"
      end
      if cname == "String"
        return "1"
      end
      if cname == "Float"
        return "1"
      end
      return "0"
    end
    if pt == "IntegerNode"
      if pred_type == "poly"
        return "(" + tmp + ".tag == SP_TAG_INT && " + tmp + ".v.i == " + @nd_value[pat_id].to_s + ")"
      end
      return tmp + " == " + @nd_value[pat_id].to_s
    end
    if pt == "StringNode"
      if pred_type == "poly"
        return "(" + tmp + ".tag == SP_TAG_STR && strcmp(" + tmp + ".v.s, " + c_string_literal(@nd_content[pat_id]) + ") == 0)"
      end
      return "strcmp(" + tmp + ", " + c_string_literal(@nd_content[pat_id]) + ") == 0"
    end
    if pt == "NilNode"
      if pred_type == "poly"
        return tmp + ".tag == SP_TAG_NIL"
      end
      return tmp + " == 0"
    end
    if pt == "TrueNode"
      if pred_type == "poly"
        return "(" + tmp + ".tag == SP_TAG_BOOL && " + tmp + ".v.b)"
      end
      return tmp + " != 0"
    end
    if pt == "FalseNode"
      if pred_type == "poly"
        return "(" + tmp + ".tag == SP_TAG_BOOL && !" + tmp + ".v.b)"
      end
      return tmp + " == 0"
    end
    if pt == "AlternationPatternNode"
      left = compile_in_pattern(@nd_left[pat_id], tmp, pred_type)
      right = compile_in_pattern(@nd_right[pat_id], tmp, pred_type)
      return "(" + left + " || " + right + ")"
    end
    "1"
  end

  def compile_return_stmt(nid)
    args_id = @nd_arguments[nid]
    if args_id >= 0
      arg_ids = get_args(args_id)
      if arg_ids.length > 0
        emit("  return " + compile_expr(arg_ids[0]) + ";")
        return
      end
    end
    emit("  return 0;")
  end

  def compile_call_stmt(nid)
    mname = @nd_name[nid]
    recv = @nd_receiver[nid]

    if mname == "puts"
      if recv < 0
        compile_puts(nid)
        return
      end
      if recv >= 0
        if @nd_type[recv] == "GlobalVariableReadNode"
          if @nd_name[recv] == "$stderr"
            compile_stderr_puts(nid)
            return
          end
        end
      end
    end
    if mname == "print"
      if recv < 0
        compile_print(nid)
        return
      end
    end

    # []=
    if mname == "[]="
      if recv >= 0
        compile_bracket_assign(nid)
        return
      end
    end

    # delete
    if mname == "delete"
      if recv >= 0
        rt = infer_type(recv)
        rc = compile_expr(recv)
        if rt == "str_int_hash"
          emit("  sp_StrIntHash_delete(" + rc + ", " + compile_arg0(nid) + ");")
          return
        end
        if rt == "str_str_hash"
          emit("  sp_StrStrHash_delete(" + rc + ", " + compile_arg0(nid) + ");")
          return
        end
      end
    end

    # << on string (mutating append)
    if mname == "<<"
      if recv >= 0
        rt = infer_type(recv)
        if rt == "string"
          @needs_string_helpers = 1
          rc = compile_expr(recv)
          val = compile_arg0(nid)
          # If receiver is a local variable, reassign
          if @nd_type[recv] == "LocalVariableReadNode"
            emit("  lv_" + @nd_name[recv] + " = sp_str_concat(lv_" + @nd_name[recv] + ", " + val + ");")
            return
          end
          if @nd_type[recv] == "InstanceVariableReadNode"
            emit("  self->" + sanitize_ivar(@nd_name[recv]) + " = sp_str_concat(self->" + sanitize_ivar(@nd_name[recv]) + ", " + val + ");")
            return
          end
        end
      end
    end

    # push
    if mname == "push"
      if recv >= 0
        rt = infer_type(recv)
        rc = compile_expr(recv)
        if rt == "int_array"
          emit("  sp_IntArray_push(" + rc + ", " + compile_arg0(nid) + ");")
          return
        end
        if rt == "str_array"
          emit("  sp_StrArray_push(" + rc + ", " + compile_arg0(nid) + ");")
          return
        end
      end
    end

    # reverse! / sort!
    if mname == "reverse!"
      if recv >= 0
        rt = infer_type(recv)
        rc = compile_expr(recv)
        if rt == "int_array"
          emit("  sp_IntArray_reverse_bang(" + rc + ");")
          return
        end
      end
    end
    if mname == "sort!"
      if recv >= 0
        rt = infer_type(recv)
        rc = compile_expr(recv)
        if rt == "int_array"
          emit("  sp_IntArray_sort_bang(" + rc + ");")
          return
        end
      end
    end

    # each with block
    if mname == "each"
      if @nd_block[nid] >= 0
        # For object types with yield-using each, use yield method call
        if recv >= 0
          ert = infer_type(recv)
          if is_obj_type(ert) == 1
            # Fall through to yield method handler below
          else
            compile_each_block(nid)
            return
          end
        else
          compile_each_block(nid)
          return
        end
      end
    end

    # times/upto/downto with block
    if mname == "times"
      if @nd_block[nid] >= 0
        compile_times_block(nid)
        return
      end
    end
    if mname == "upto"
      if @nd_block[nid] >= 0
        compile_upto_block(nid)
        return
      end
    end
    if mname == "downto"
      if @nd_block[nid] >= 0
        compile_downto_block(nid)
        return
      end
    end

    # reduce/inject
    if mname == "reduce"
      if @nd_block[nid] >= 0
        compile_reduce_block(nid)
        return
      end
    end
    if mname == "inject"
      if @nd_block[nid] >= 0
        compile_reduce_block(nid)
        return
      end
    end

    # reject
    if mname == "reject"
      if @nd_block[nid] >= 0
        compile_reject_block(nid)
        return
      end
    end

    # loop
    if mname == "loop"
      if @nd_block[nid] >= 0
        old = @in_loop
        @in_loop = 1
        emit("  while (1) {")
        @indent = @indent + 1
        compile_stmts_body(@nd_body[@nd_block[nid]])
        @indent = @indent - 1
        emit("  }")
        @in_loop = old
        return
      end
    end

    # raise
    if mname == "raise"
      if recv < 0
        @needs_setjmp = 1
        args_id = @nd_arguments[nid]
        if args_id >= 0
          arg_ids = get_args(args_id)
          if arg_ids.length >= 2
            # raise ClassName, "message" - use the message with class
            if @nd_type[arg_ids[0]] == "ConstantReadNode"
              emit("  sp_raise_cls(\"" + @nd_name[arg_ids[0]] + "\", " + compile_expr(arg_ids[1]) + ");")
            else
              emit("  sp_raise(" + compile_expr(arg_ids[1]) + ");")
            end
          else
            if arg_ids.length == 1
              # raise "message" or raise ClassName
              if @nd_type[arg_ids[0]] == "ConstantReadNode"
                emit("  sp_raise(\"" + @nd_name[arg_ids[0]] + "\");")
              else
                emit("  sp_raise(" + compile_expr(arg_ids[0]) + ");")
              end
            else
              emit("  sp_raise(\"RuntimeError\");")
            end
          end
        else
          emit("  sp_raise(\"RuntimeError\");")
        end
        return
      end
    end

    # system
    if mname == "system"
      if recv < 0
        @needs_file_io = 1
        emit("  fflush(stdout);")
        emit("  sp_last_status = system(" + compile_arg0(nid) + ");")
        return
      end
    end

    # trap (just ignore)
    if mname == "trap"
      if recv < 0
        return
      end
    end

    # catch/throw
    if mname == "catch"
      if recv < 0
        if @nd_block[nid] >= 0
          compile_catch_stmt(nid)
          return
        end
      end
    end
    if mname == "throw"
      if recv < 0
        compile_throw_stmt(nid)
        return
      end
    end

    # File operations
    if recv >= 0
      if @nd_type[recv] == "ConstantReadNode"
        rcname = @nd_name[recv]
        if rcname == "File"
          if mname == "write"
            @needs_file_io = 1
            args_id = @nd_arguments[nid]
            arg_ids = []
            if args_id >= 0
              arg_ids = get_args(args_id)
            end
            a0 = "0"
            a1 = "0"
            if arg_ids.length >= 1
              a0 = compile_expr(arg_ids[0])
            end
            if arg_ids.length >= 2
              a1 = compile_expr(arg_ids[1])
            end
            emit("  sp_file_write(" + a0 + ", " + a1 + ");")
            return
          end
          if mname == "delete"
            @needs_file_io = 1
            emit("  sp_file_delete(" + compile_arg0(nid) + ");")
            return
          end
        end
      end
    end

    # exit
    if mname == "exit"
      if recv < 0
        val = compile_arg0(nid)
        emit("  exit(" + val + ");")
        return
      end
    end

    # attr_writer: obj.x = val
    if recv >= 0
      if mname.length > 1
        if mname[mname.length - 1] == "="
          bname = mname[0, mname.length - 1]
          rt = infer_type(recv)
          if is_obj_type(rt) == 1
            rc = compile_expr(recv)
            emit("  " + rc + "->" + bname + " = " + compile_arg0(nid) + ";")
            return
          end
        end
      end
    end

    # map with block
    if mname == "map"
      if @nd_block[nid] >= 0
        compile_map_block(nid)
        return
      end
    end

    # select with block
    if mname == "select"
      if @nd_block[nid] >= 0
        compile_select_block(nid)
        return
      end
    end

    # User-defined yield function called with block
    if @nd_block[nid] >= 0
      if recv < 0
        mi = find_method_idx(mname)
        if mi >= 0
          if @meth_has_yield[mi] == 1
            compile_yield_call_stmt(nid, mi)
            return
          end
        end
      end
      # Class method with yield
      if recv >= 0
        rtype = infer_type(recv)
        if is_obj_type(rtype) == 1
          cn = rtype[4, rtype.length - 4]
          cci = find_class_idx(cn)
          if cci >= 0
            midx = cls_find_method_direct(cci, mname)
            if midx >= 0
              if cls_method_has_yield(cci, midx) == 1
                compile_yield_method_call_stmt(nid, cci, midx, mname)
                return
              end
            end
            # Check parent
            if @cls_parents[cci] != ""
              pci = find_class_idx(@cls_parents[cci])
              if pci >= 0
                pidx = cls_find_method_direct(pci, mname)
                if pidx >= 0
                  if cls_method_has_yield(pci, pidx) == 1
                    compile_yield_method_call_stmt(nid, pci, pidx, mname)
                    return
                  end
                end
              end
            end
          end
        end
      end
    end

    # General
    val = compile_expr(nid)
    if val != "0"
      emit("  " + val + ";")
    end
  end

  def compile_bracket_assign(nid)
    recv = @nd_receiver[nid]
    rt = infer_type(recv)
    rc = compile_expr(recv)
    args_id = @nd_arguments[nid]
    arg_ids = []
    if args_id >= 0
      arg_ids = get_args(args_id)
    end
    idx = "0"
    val = "0"
    if arg_ids.length >= 1
      idx = compile_expr(arg_ids[0])
    end
    if arg_ids.length >= 2
      val = compile_expr(arg_ids[1])
    end
    if rt == "int_array"
      emit("  sp_IntArray_set(" + rc + ", " + idx + ", " + val + ");")
      return
    end
    if rt == "str_array"
      emit("  sp_StrArray_set(" + rc + ", " + idx + ", " + val + ");")
      return
    end
    if rt == "str_int_hash"
      emit("  sp_StrIntHash_set(" + rc + ", " + idx + ", " + val + ");")
      return
    end
    if rt == "str_str_hash"
      emit("  sp_StrStrHash_set(" + rc + ", " + idx + ", " + val + ");")
      return
    end
  end

  def compile_puts(nid)
    args_id = @nd_arguments[nid]
    if args_id < 0
      emit("  putchar('\\n');")
      return
    end
    arg_ids = get_args(args_id)
    if arg_ids.length == 0
      emit("  putchar('\\n');")
      return
    end
    k = 0
    while k < arg_ids.length
      aid = arg_ids[k]
      at = infer_type(aid)
      val = compile_expr(aid)
      if at == "poly"
        @needs_rb_value = 1
        emit("  sp_poly_puts(" + val + ");")
        k = k + 1
        next
      end
      if at == "int"
        emit("  printf(\"%lld\\n\", (long long)" + val + ");")
      else
        if at == "float"
          emit("  printf(\"%g\\n\", " + val + ");")
        else
          if at == "string"
            emit("  { const char *_ps = " + val + "; if (_ps) { fputs(_ps, stdout); if (!*_ps || _ps[strlen(_ps)-1] != '\\n') putchar('\\n'); } else putchar('\\n'); }")
          else
            if at == "bool"
              emit("  puts(" + val + " ? \"true\" : \"false\");")
            else
              if is_obj_type(at) == 1
                cname = at[4, at.length - 4]
                owner = find_method_owner(find_class_idx(cname), "to_s")
                if owner != ""
                  sv = "sp_" + owner + "_to_s(" + (owner == cname ? val : "(sp_" + owner + " *)" + val) + ")"
                  emit("  { const char *_ps = " + sv + "; if (_ps) { fputs(_ps, stdout); if (!*_ps || _ps[strlen(_ps)-1] != '\\n') putchar('\\n'); } else putchar('\\n'); }")
                else
                  emit("  printf(\"%lld\\n\", (long long)(mrb_int)" + val + ");")
                end
              else
                emit("  printf(\"%lld\\n\", (long long)" + val + ");")
              end
            end
          end
        end
      end
      k = k + 1
    end
  end

  def compile_stderr_puts(nid)
    args_id = @nd_arguments[nid]
    if args_id < 0
      emit("  fputc('\\n', stderr);")
      return
    end
    arg_ids = get_args(args_id)
    k = 0
    while k < arg_ids.length
      at = infer_type(arg_ids[k])
      val = compile_expr(arg_ids[k])
      if at == "string"
        emit("  fprintf(stderr, \"%s\\n\", " + val + ");")
      else
        emit("  fprintf(stderr, \"%lld\\n\", (long long)" + val + ");")
      end
      k = k + 1
    end
  end

  def compile_print(nid)
    args_id = @nd_arguments[nid]
    if args_id < 0
      return
    end
    arg_ids = get_args(args_id)
    k = 0
    while k < arg_ids.length
      at = infer_type(arg_ids[k])
      val = compile_expr(arg_ids[k])
      if at == "int"
        emit("  printf(\"%lld\", (long long)" + val + ");")
      else
        if at == "string"
          emit("  fputs(" + val + ", stdout);")
        else
          emit("  printf(\"%lld\", (long long)" + val + ");")
        end
      end
      k = k + 1
    end
  end

  def get_block_param(nid, idx)
    blk = @nd_block[nid]
    if blk < 0
      return ""
    end
    params = @nd_parameters[blk]
    if params < 0
      return ""
    end
    inner = @nd_parameters[params]
    if inner < 0
      return ""
    end
    reqs = parse_id_list(@nd_requireds[inner])
    if idx < reqs.length
      return @nd_name[reqs[idx]]
    end
    ""
  end

  def compile_each_block(nid)
    old = @in_loop
    @in_loop = 1
    rt = infer_type(@nd_receiver[nid])
    rc = compile_expr(@nd_receiver[nid])
    bp1 = get_block_param(nid, 0)
    bp2 = get_block_param(nid, 1)
    if bp1 == ""
      bp1 = "_x"
    end

    if rt == "int_array"
      tmp = new_temp
      emit("  for (mrb_int " + tmp + " = 0; " + tmp + " < sp_IntArray_length(" + rc + "); " + tmp + "++) {")
      emit("    lv_" + bp1 + " = sp_IntArray_get(" + rc + ", " + tmp + ");")
      @indent = @indent + 1
      compile_stmts_body(@nd_body[@nd_block[nid]])
      @indent = @indent - 1
      emit("  }")
    end
    if rt == "str_array"
      tmp = new_temp
      emit("  for (mrb_int " + tmp + " = 0; " + tmp + " < sp_StrArray_length(" + rc + "); " + tmp + "++) {")
      emit("    lv_" + bp1 + " = sp_StrArray_get(" + rc + ", " + tmp + ");")
      @indent = @indent + 1
      compile_stmts_body(@nd_body[@nd_block[nid]])
      @indent = @indent - 1
      emit("  }")
    end
    if rt == "str_int_hash"
      tmp = new_temp
      emit("  for (mrb_int " + tmp + " = 0; " + tmp + " < " + rc + "->len; " + tmp + "++) {")
      emit("    lv_" + bp1 + " = " + rc + "->keys[" + tmp + "];")
      if bp2 != ""
        emit("    lv_" + bp2 + " = " + rc + "->vals[" + tmp + "];")
      end
      @indent = @indent + 1
      compile_stmts_body(@nd_body[@nd_block[nid]])
      @indent = @indent - 1
      emit("  }")
    end
    if rt == "str_str_hash"
      tmp = new_temp
      emit("  for (mrb_int " + tmp + " = 0; " + tmp + " < " + rc + "->len; " + tmp + "++) {")
      emit("    lv_" + bp1 + " = " + rc + "->keys[" + tmp + "];")
      if bp2 != ""
        emit("    lv_" + bp2 + " = " + rc + "->vals[" + tmp + "];")
      end
      @indent = @indent + 1
      compile_stmts_body(@nd_body[@nd_block[nid]])
      @indent = @indent - 1
      emit("  }")
    end
    if rt == "range"
      tmp = new_temp
      tmp2 = new_temp
      emit("  sp_Range " + tmp2 + " = " + rc + ";")
      emit("  for (lv_" + bp1 + " = " + tmp2 + ".first; lv_" + bp1 + " <= " + tmp2 + ".last; lv_" + bp1 + "++) {")
      @indent = @indent + 1
      compile_stmts_body(@nd_body[@nd_block[nid]])
      @indent = @indent - 1
      emit("  }")
    end
    @in_loop = old
  end

  def compile_times_block(nid)
    old = @in_loop
    @in_loop = 1
    rc = compile_expr(@nd_receiver[nid])
    bp1 = get_block_param(nid, 0)
    tmp = new_temp
    emit("  for (mrb_int " + tmp + " = 0; " + tmp + " < " + rc + "; " + tmp + "++) {")
    if bp1 != ""
      emit("    lv_" + bp1 + " = " + tmp + ";")
    end
    @indent = @indent + 1
    compile_stmts_body(@nd_body[@nd_block[nid]])
    @indent = @indent - 1
    emit("  }")
    @in_loop = old
  end

  def compile_upto_block(nid)
    old = @in_loop
    @in_loop = 1
    rc = compile_expr(@nd_receiver[nid])
    lim = compile_arg0(nid)
    bp1 = get_block_param(nid, 0)
    tmp = new_temp
    emit("  for (mrb_int " + tmp + " = " + rc + "; " + tmp + " <= " + lim + "; " + tmp + "++) {")
    if bp1 != ""
      emit("    lv_" + bp1 + " = " + tmp + ";")
    end
    @indent = @indent + 1
    compile_stmts_body(@nd_body[@nd_block[nid]])
    @indent = @indent - 1
    emit("  }")
    @in_loop = old
  end

  def compile_downto_block(nid)
    old = @in_loop
    @in_loop = 1
    rc = compile_expr(@nd_receiver[nid])
    lim = compile_arg0(nid)
    bp1 = get_block_param(nid, 0)
    tmp = new_temp
    emit("  for (mrb_int " + tmp + " = " + rc + "; " + tmp + " >= " + lim + "; " + tmp + "--) {")
    if bp1 != ""
      emit("    lv_" + bp1 + " = " + tmp + ";")
    end
    @indent = @indent + 1
    compile_stmts_body(@nd_body[@nd_block[nid]])
    @indent = @indent - 1
    emit("  }")
    @in_loop = old
  end

  def compile_map_expr(nid)
    # Emit the map loop as side effects, return result array
    compile_map_block(nid)
    # The map_block stores result in a temp - we need to return it
    # Actually, compile_map_block emits into current output but doesn't return the temp name.
    # Let's use a different approach: inline and return temp
    rt = infer_type(@nd_receiver[nid])
    rc = compile_expr(@nd_receiver[nid])
    bp1 = get_block_param(nid, 0)
    if bp1 == ""
      bp1 = "_x"
    end
    tmp_arr = new_temp
    tmp_i = new_temp
    if rt == "int_array"
      @needs_int_array = 1
      @needs_gc = 1
      emit("  sp_IntArray *" + tmp_arr + " = sp_IntArray_new();")
      emit("  for (mrb_int " + tmp_i + " = 0; " + tmp_i + " < sp_IntArray_length(" + rc + "); " + tmp_i + "++) {")
      emit("    lv_" + bp1 + " = sp_IntArray_get(" + rc + ", " + tmp_i + ");")
      @indent = @indent + 1
      blk = @nd_block[nid]
      if blk >= 0
        body = @nd_body[blk]
        if body >= 0
          stmts = get_stmts(body)
          if stmts.length > 0
            last = stmts[stmts.length - 1]
            val = compile_expr(last)
            emit("  sp_IntArray_push(" + tmp_arr + ", " + val + ");")
          end
        end
      end
      @indent = @indent - 1
      emit("  }")
      return tmp_arr
    end
    "0"
  end

  def compile_select_expr(nid)
    rt = infer_type(@nd_receiver[nid])
    rc = compile_expr(@nd_receiver[nid])
    bp1 = get_block_param(nid, 0)
    if bp1 == ""
      bp1 = "_x"
    end
    tmp_arr = new_temp
    tmp_i = new_temp
    if rt == "int_array"
      @needs_int_array = 1
      @needs_gc = 1
      emit("  sp_IntArray *" + tmp_arr + " = sp_IntArray_new();")
      emit("  for (mrb_int " + tmp_i + " = 0; " + tmp_i + " < sp_IntArray_length(" + rc + "); " + tmp_i + "++) {")
      emit("    lv_" + bp1 + " = sp_IntArray_get(" + rc + ", " + tmp_i + ");")
      @indent = @indent + 1
      blk = @nd_block[nid]
      if blk >= 0
        body = @nd_body[blk]
        if body >= 0
          stmts = get_stmts(body)
          if stmts.length > 0
            last = stmts[stmts.length - 1]
            cond = compile_expr(last)
            emit("  if (" + cond + ") sp_IntArray_push(" + tmp_arr + ", lv_" + bp1 + ");")
          end
        end
      end
      @indent = @indent - 1
      emit("  }")
      return tmp_arr
    end
    "0"
  end

  def compile_reduce_expr(nid)
    # Emit the reduce loop as side effects, return accumulator
    compile_reduce_block(nid)
    bp1 = get_block_param(nid, 0)
    if bp1 == ""
      bp1 = "_acc"
    end
    "lv_" + bp1
  end

  def compile_reduce_block(nid)
    rc = compile_expr(@nd_receiver[nid])
    init_val = compile_arg0(nid)
    bp1 = get_block_param(nid, 0)
    bp2 = get_block_param(nid, 1)
    if bp1 == ""
      bp1 = "_acc"
    end
    if bp2 == ""
      bp2 = "_x"
    end
    emit("  lv_" + bp1 + " = " + init_val + ";")
    rt = infer_type(@nd_receiver[nid])
    if rt == "int_array"
      tmp = new_temp
      emit("  for (mrb_int " + tmp + " = 0; " + tmp + " < sp_IntArray_length(" + rc + "); " + tmp + "++) {")
      emit("    lv_" + bp2 + " = sp_IntArray_get(" + rc + ", " + tmp + ");")
      @indent = @indent + 1
      blk = @nd_block[nid]
      if blk >= 0
        body = @nd_body[blk]
        if body >= 0
          stmts = get_stmts(body)
          if stmts.length > 0
            last = stmts[stmts.length - 1]
            val = compile_expr(last)
            emit("  lv_" + bp1 + " = " + val + ";")
          end
        end
      end
      @indent = @indent - 1
      emit("  }")
    end
  end

  def compile_reject_expr(nid)
    rc = compile_expr(@nd_receiver[nid])
    bp1 = get_block_param(nid, 0)
    if bp1 == ""
      bp1 = "_x"
    end
    rt = infer_type(@nd_receiver[nid])
    if rt == "int_array"
      @needs_int_array = 1
      tmp_arr = new_temp
      emit("  sp_IntArray *" + tmp_arr + " = sp_IntArray_new();")
      tmp_i = new_temp
      emit("  for (mrb_int " + tmp_i + " = 0; " + tmp_i + " < sp_IntArray_length(" + rc + "); " + tmp_i + "++) {")
      emit("    lv_" + bp1 + " = sp_IntArray_get(" + rc + ", " + tmp_i + ");")
      @indent = @indent + 1
      blk = @nd_block[nid]
      if blk >= 0
        body = @nd_body[blk]
        if body >= 0
          stmts = get_stmts(body)
          if stmts.length > 0
            last = stmts[stmts.length - 1]
            cond = compile_expr(last)
            emit("  if (!(" + cond + ")) sp_IntArray_push(" + tmp_arr + ", lv_" + bp1 + ");")
          end
        end
      end
      @indent = @indent - 1
      emit("  }")
      return tmp_arr
    end
    "0"
  end

  def compile_reject_block(nid)
    rc = compile_expr(@nd_receiver[nid])
    bp1 = get_block_param(nid, 0)
    if bp1 == ""
      bp1 = "_x"
    end
    rt = infer_type(@nd_receiver[nid])
    if rt == "int_array"
      @needs_int_array = 1
      tmp_arr = new_temp
      emit("  sp_IntArray *" + tmp_arr + " = sp_IntArray_new();")
      tmp_i = new_temp
      emit("  for (mrb_int " + tmp_i + " = 0; " + tmp_i + " < sp_IntArray_length(" + rc + "); " + tmp_i + "++) {")
      emit("    lv_" + bp1 + " = sp_IntArray_get(" + rc + ", " + tmp_i + ");")
      @indent = @indent + 1
      blk = @nd_block[nid]
      if blk >= 0
        body = @nd_body[blk]
        if body >= 0
          stmts = get_stmts(body)
          if stmts.length > 0
            last = stmts[stmts.length - 1]
            cond = compile_expr(last)
            emit("  if (!(" + cond + ")) sp_IntArray_push(" + tmp_arr + ", lv_" + bp1 + ");")
          end
        end
      end
      @indent = @indent - 1
      emit("  }")
    end
  end

  def compile_sprintf_call(nid)
    @needs_string_helpers = 1
    args_id = @nd_arguments[nid]
    if args_id < 0
      return "\"\""
    end
    arg_ids = get_args(args_id)
    if arg_ids.length == 0
      return "\"\""
    end
    # First arg is format string, rest are values
    fmt = compile_expr(arg_ids[0])
    result = "sp_sprintf(" + fmt
    k = 1
    while k < arg_ids.length
      at = infer_type(arg_ids[k])
      if at == "float"
        result = result + ", " + compile_expr(arg_ids[k])
      else
        result = result + ", " + compile_expr(arg_ids[k])
      end
      k = k + 1
    end
    result + ")"
  end

  def compile_catch_expr(nid)
    @needs_setjmp = 1
    tag = compile_arg0(nid)
    blk = @nd_block[nid]
    tmp = new_temp

    emit("  mrb_int " + tmp + " = 0;")
    emit("  sp_catch_tag[sp_catch_top] = " + tag + ";")
    emit("  sp_catch_top++;")
    emit("  if (setjmp(sp_catch_stack[sp_catch_top-1]) == 0) {")
    @indent = @indent + 1
    if blk >= 0
      body = @nd_body[blk]
      if body >= 0
        stmts = get_stmts(body)
        # Compile all but last as statements
        k = 0
        while k < stmts.length - 1
          compile_stmt(stmts[k])
          k = k + 1
        end
        if stmts.length > 0
          last = stmts[stmts.length - 1]
          emit("  " + tmp + " = " + compile_expr(last) + ";")
        end
      end
    end
    @indent = @indent - 1
    emit("    sp_catch_top--;")
    emit("  } else {")
    emit("    sp_catch_top--;")
    emit("    " + tmp + " = sp_catch_val[sp_catch_top];")
    emit("  }")
    tmp
  end

  def compile_catch_stmt(nid)
    @needs_setjmp = 1
    # catch(:tag) do ... end
    tag = compile_arg0(nid)
    blk = @nd_block[nid]
    bp1 = get_block_param(nid, 0)

    emit("  sp_catch_tag[sp_catch_top] = " + tag + ";")
    emit("  sp_catch_top++;")
    emit("  if (setjmp(sp_catch_stack[sp_catch_top-1]) == 0) {")
    @indent = @indent + 1
    if blk >= 0
      compile_stmts_body(@nd_body[blk])
    end
    @indent = @indent - 1
    emit("    sp_catch_top--;")
    emit("  } else {")
    emit("    sp_catch_top--;")
    emit("  }")
  end

  def compile_throw_stmt(nid)
    @needs_setjmp = 1
    args_id = @nd_arguments[nid]
    arg_ids = []
    if args_id >= 0
      arg_ids = get_args(args_id)
    end
    tag = "\"\""
    val = "0"
    if arg_ids.length >= 1
      tag = compile_expr(arg_ids[0])
    end
    if arg_ids.length >= 2
      val = compile_expr(arg_ids[1])
    end
    emit("  sp_throw(" + tag + ", " + val + ");")
  end

  def compile_begin_stmt(nid)
    @needs_setjmp = 1
    has_rescue = @nd_rescue_clause[nid] >= 0
    has_ensure = @nd_ensure_clause[nid] >= 0

    # Check if rescue body has retry
    has_retry = 0
    rc = @nd_rescue_clause[nid]
    if rc >= 0
      if body_has_retry(@nd_body[rc]) == 1
        has_retry = 1
      end
    end

    if has_retry == 1
      emit("  for (;;) {")
      @indent = @indent + 1
    end

    if has_rescue
      emit("  sp_exc_top++;")
      emit("  if (setjmp(sp_exc_stack[sp_exc_top-1]) == 0) {")
      @indent = @indent + 1
      compile_stmts_body(@nd_body[nid])
      @indent = @indent - 1
      emit("    sp_exc_top--;")
      if has_retry == 1
        emit("    break;")
      end

      rc = @nd_rescue_clause[nid]
      if rc >= 0
        emit("  } else {")
        emit("    sp_exc_top--;")
        @indent = @indent + 1
        # Check for multiple rescue clauses with exception types
        compile_rescue_chain(rc, has_retry)
        @indent = @indent - 1
      end
      emit("  }")
    else
      compile_stmts_body(@nd_body[nid])
    end

    if has_retry == 1
      @indent = @indent - 1
      emit("  }")
    end

    if has_ensure
      ec = @nd_ensure_clause[nid]
      if ec >= 0
        compile_stmts_body(@nd_body[ec])
      end
    end
  end

  def compile_rescue_chain(rc, has_retry)
    # Check for exception type matching
    exc_types = parse_id_list(@nd_exceptions[rc])
    ref = @nd_reference[rc]
    has_type_check = 0
    if exc_types.length > 0
      has_type_check = 1
      # Build condition: sp_exc_is_a(sp_last_exc_cls, "ClassName")
      cond = ""
      k = 0
      while k < exc_types.length
        if k > 0
          cond = cond + " || "
        end
        cond = cond + "sp_exc_is_a((const char*)sp_last_exc_cls, \"" + @nd_name[exc_types[k]] + "\")"
        k = k + 1
      end
      emit("  if (" + cond + ") {")
      @indent = @indent + 1
    end
    if ref >= 0
      rname = @nd_name[ref]
      emit("  lv_" + rname + " = sp_exc_msg[sp_exc_top];")
    end
    compile_rescue_body(@nd_body[rc], has_retry)
    if has_type_check == 1
      @indent = @indent - 1
      # Check for subsequent rescue
      sub = @nd_subsequent[rc]
      if sub >= 0
        emit("  } else {")
        @indent = @indent + 1
        compile_rescue_chain(sub, has_retry)
        @indent = @indent - 1
      end
      emit("  }")
    else
      # No type check - bare rescue, catches all
      sub = @nd_subsequent[rc]
      # Ignore subsequent since bare rescue catches all
    end
  end

  def compile_rescue_body(nid, has_retry)
    if nid < 0
      return
    end
    stmts = get_stmts(nid)
    k = 0
    while k < stmts.length
      compile_stmt(stmts[k])
      k = k + 1
    end
    if has_retry == 1
      # If we get here without a retry (continue), break out of the loop
      emit("  break;")
    end
  end

  def body_has_retry(nid)
    if nid < 0
      return 0
    end
    if @nd_type[nid] == "RetryNode"
      return 1
    end
    stmts = parse_id_list(@nd_stmts[nid])
    k = 0
    while k < stmts.length
      if body_has_retry(stmts[k]) == 1
        return 1
      end
      k = k + 1
    end
    if @nd_body[nid] >= 0
      if body_has_retry(@nd_body[nid]) == 1
        return 1
      end
    end
    if @nd_subsequent[nid] >= 0
      if body_has_retry(@nd_subsequent[nid]) == 1
        return 1
      end
    end
    0
  end

  def compile_yield_stmt(nid)
    args_id = @nd_arguments[nid]
    arg_exprs = ""
    if args_id >= 0
      aids = get_args(args_id)
      k = 0
      while k < aids.length
        if k > 0
          arg_exprs = arg_exprs + ", "
        end
        arg_exprs = arg_exprs + compile_expr(aids[k])
        k = k + 1
      end
    end
    if arg_exprs != ""
      emit("  if (_block) _block(" + arg_exprs + ", _benv);")
    else
      emit("  if (_block) _block(0, _benv);")
    end
  end

  def compile_yield_call_stmt(nid, mi)
    # Call a yield-using top-level function with a block
    # Inline the function body, replacing yield with block body
    blk = @nd_block[nid]
    if blk < 0
      return
    end

    # Get block params
    bp_names = "".split(",")
    bp = @nd_parameters[blk]
    if bp >= 0
      inner = @nd_parameters[bp]
      if inner >= 0
        reqs = parse_id_list(@nd_requireds[inner])
        k = 0
        while k < reqs.length
          bp_names.push(@nd_name[reqs[k]])
          k = k + 1
        end
      end
    end

    args_id = @nd_arguments[nid]
    arg_ids = []
    if args_id >= 0
      arg_ids = get_args(args_id)
    end

    # Declare and set the function's params as new temp vars
    pnames = @meth_param_names[mi].split(",")
    ptypes = @meth_param_types[mi].split(",")
    # Create unique temp names for function params to avoid collision
    @block_counter = @block_counter + 1
    suffix = "_y" + @block_counter.to_s
    param_map_from = "".split(",")
    param_map_to = "".split(",")
    k = 0
    while k < pnames.length
      pt = "int"
      if k < ptypes.length
        pt = ptypes[k]
      end
      tname = pnames[k] + suffix
      val = "0"
      if k < arg_ids.length
        val = compile_expr(arg_ids[k])
      end
      emit("  " + c_type(pt) + " lv_" + tname + " = " + val + ";")
      param_map_from.push(pnames[k])
      param_map_to.push(tname)
      declare_var(tname, pt)
      k = k + 1
    end

    # Also need to declare the function's local vars
    bid = @meth_body_ids[mi]
    if bid >= 0
      flocals_n = "".split(",")
      flocals_t = "".split(",")
      scan_locals(bid, flocals_n, flocals_t, pnames)
      k = 0
      while k < flocals_n.length
        tname = flocals_n[k] + suffix
        emit("  " + c_type(flocals_t[k]) + " lv_" + tname + " = " + c_default_val(flocals_t[k]) + ";")
        param_map_from.push(flocals_n[k])
        param_map_to.push(tname)
        declare_var(tname, flocals_t[k])
        k = k + 1
      end
    end

    # Compile function body, replacing yield with block body
    # and renaming function locals to temp names
    if bid >= 0
      stmts = get_stmts(bid)
      k = 0
      while k < stmts.length
        compile_stmt_with_block(stmts[k], blk, bp_names, param_map_from, param_map_to)
        k = k + 1
      end
    end
  end

  def compile_stmt_with_block(nid, blk, bp_names, map_from, map_to)
    if nid < 0
      return
    end
    t = @nd_type[nid]
    if t == "YieldNode"
      # Replace yield with the block body
      args_id = @nd_arguments[nid]
      if args_id >= 0
        aids = get_args(args_id)
        k = 0
        while k < aids.length
          if k < bp_names.length
            emit("  lv_" + bp_names[k] + " = " + compile_expr_remap(aids[k], map_from, map_to) + ";")
          end
          k = k + 1
        end
      end
      body = @nd_body[blk]
      if body >= 0
        stmts = get_stmts(body)
        sk = 0
        while sk < stmts.length
          compile_stmt(stmts[sk])
          sk = sk + 1
        end
      end
      return
    end
    if t == "LocalVariableWriteNode"
      lname = @nd_name[nid]
      rname = remap_local(lname, map_from, map_to)
      val = compile_expr_remap(@nd_expression[nid], map_from, map_to)
      emit("  lv_" + rname + " = " + val + ";")
      return
    end
    if t == "LocalVariableOperatorWriteNode"
      lname = @nd_name[nid]
      rname = remap_local(lname, map_from, map_to)
      op = @nd_binop[nid]
      val = compile_expr_remap(@nd_expression[nid], map_from, map_to)
      if op == "+"
        emit("  lv_" + rname + " += " + val + ";")
      end
      if op == "-"
        emit("  lv_" + rname + " -= " + val + ";")
      end
      if op == "*"
        emit("  lv_" + rname + " *= " + val + ";")
      end
      return
    end
    if t == "WhileNode"
      old = @in_loop
      @in_loop = 1
      cond = compile_expr_remap(@nd_predicate[nid], map_from, map_to)
      emit("  while (" + cond + ") {")
      @indent = @indent + 1
      body = @nd_body[nid]
      if body >= 0
        stmts = get_stmts(body)
        sk = 0
        while sk < stmts.length
          compile_stmt_with_block(stmts[sk], blk, bp_names, map_from, map_to)
          sk = sk + 1
        end
      end
      @indent = @indent - 1
      emit("  }")
      @in_loop = old
      return
    end
    if t == "IfNode"
      cond = compile_expr_remap(@nd_predicate[nid], map_from, map_to)
      emit("  if (" + cond + ") {")
      @indent = @indent + 1
      body = @nd_body[nid]
      if body >= 0
        stmts = get_stmts(body)
        sk = 0
        while sk < stmts.length
          compile_stmt_with_block(stmts[sk], blk, bp_names, map_from, map_to)
          sk = sk + 1
        end
      end
      @indent = @indent - 1
      sub = @nd_subsequent[nid]
      if sub >= 0
        if @nd_type[sub] == "ElseNode"
          emit("  } else {")
          @indent = @indent + 1
          eb = @nd_body[sub]
          if eb >= 0
            estmts = get_stmts(eb)
            sk = 0
            while sk < estmts.length
              compile_stmt_with_block(estmts[sk], blk, bp_names, map_from, map_to)
              sk = sk + 1
            end
          end
          @indent = @indent - 1
        else
          emit("  } else")
          compile_stmt_with_block(sub, blk, bp_names, map_from, map_to)
          return
        end
      end
      emit("  }")
      return
    end
    if t == "CallNode"
      # Check if block_given? with remap
      if @nd_name[nid] == "block_given?"
        if @nd_receiver[nid] < 0
          # In inlined context, block IS given, do nothing
          return
        end
      end
      # Handle nested each/times with yield inside block
      if @nd_block[nid] >= 0
        mname2 = @nd_name[nid]
        if mname2 == "each"
          # Compile the each loop, but inside the block body, recurse with yield replacement
          compile_each_with_yield_inline(nid, blk, bp_names, map_from, map_to)
          return
        end
      end
      # Compile call with remapping for args
      val = compile_expr_remap(nid, map_from, map_to)
      if val != "0"
        emit("  " + val + ";")
      end
      return
    end
    if t == "ReturnNode"
      # In inlined context, return becomes a value assignment
      # but for simplicity, just skip
      return
    end
    # Default: for expression statements, use remap
    val = compile_expr_remap(nid, map_from, map_to)
    if val != "0"
      emit("  " + val + ";")
    end
  end

  def remap_local(name, map_from, map_to)
    k = 0
    while k < map_from.length
      if map_from[k] == name
        return map_to[k]
      end
      k = k + 1
    end
    name
  end

  def compile_expr_remap(nid, map_from, map_to)
    if nid < 0
      return "0"
    end
    t = @nd_type[nid]
    if t == "LocalVariableReadNode"
      rname = remap_local(@nd_name[nid], map_from, map_to)
      return "lv_" + rname
    end
    if t == "InstanceVariableReadNode"
      # Remap self to the _yself variable
      self_name = remap_local("_self_", map_from, map_to)
      return self_name + "->" + sanitize_ivar(@nd_name[nid])
    end
    if t == "SelfNode"
      return remap_local("_self_", map_from, map_to)
    end
    if t == "CallNode"
      if @nd_name[nid] == "block_given?"
        if @nd_receiver[nid] < 0
          return "1"
        end
      end
      # For operators with remapped locals
      mname = @nd_name[nid]
      recv = @nd_receiver[nid]
      if recv >= 0
        if mname == "+"
          return "(" + compile_expr_remap(recv, map_from, map_to) + " + " + compile_expr_remap_arg0(nid, map_from, map_to) + ")"
        end
        if mname == "-"
          args_id = @nd_arguments[nid]
          if args_id < 0
            return "(-" + compile_expr_remap(recv, map_from, map_to) + ")"
          end
          return "(" + compile_expr_remap(recv, map_from, map_to) + " - " + compile_expr_remap_arg0(nid, map_from, map_to) + ")"
        end
        if mname == "*"
          return "(" + compile_expr_remap(recv, map_from, map_to) + " * " + compile_expr_remap_arg0(nid, map_from, map_to) + ")"
        end
        if mname == "/"
          return "(" + compile_expr_remap(recv, map_from, map_to) + " / " + compile_expr_remap_arg0(nid, map_from, map_to) + ")"
        end
        if mname == "%"
          return "sp_imod(" + compile_expr_remap(recv, map_from, map_to) + ", " + compile_expr_remap_arg0(nid, map_from, map_to) + ")"
        end
        if mname == "<"
          return "(" + compile_expr_remap(recv, map_from, map_to) + " < " + compile_expr_remap_arg0(nid, map_from, map_to) + ")"
        end
        if mname == ">"
          return "(" + compile_expr_remap(recv, map_from, map_to) + " > " + compile_expr_remap_arg0(nid, map_from, map_to) + ")"
        end
        if mname == "<="
          return "(" + compile_expr_remap(recv, map_from, map_to) + " <= " + compile_expr_remap_arg0(nid, map_from, map_to) + ")"
        end
        if mname == ">="
          return "(" + compile_expr_remap(recv, map_from, map_to) + " >= " + compile_expr_remap_arg0(nid, map_from, map_to) + ")"
        end
        if mname == "=="
          return "(" + compile_expr_remap(recv, map_from, map_to) + " == " + compile_expr_remap_arg0(nid, map_from, map_to) + ")"
        end
        if mname == "!="
          return "(" + compile_expr_remap(recv, map_from, map_to) + " != " + compile_expr_remap_arg0(nid, map_from, map_to) + ")"
        end
      end
    end
    # Fallback: compile normally
    compile_expr(nid)
  end

  def compile_expr_remap_arg0(nid, map_from, map_to)
    args_id = @nd_arguments[nid]
    if args_id >= 0
      arg_ids = get_args(args_id)
      if arg_ids.length > 0
        return compile_expr_remap(arg_ids[0], map_from, map_to)
      end
    end
    "0"
  end

  def compile_yield_method_call_stmt(nid, cci, midx, mname)
    # Call a yield-using class method with a block - inline the method body
    blk = @nd_block[nid]
    if blk < 0
      return
    end
    bp_names = "".split(",")
    bp = @nd_parameters[blk]
    if bp >= 0
      inner = @nd_parameters[bp]
      if inner >= 0
        reqs = parse_id_list(@nd_requireds[inner])
        k = 0
        while k < reqs.length
          bp_names.push(@nd_name[reqs[k]])
          k = k + 1
        end
      end
    end

    recv = @nd_receiver[nid]
    rc = compile_expr(recv)

    bodies = @cls_meth_bodies[cci].split(";")
    bid = -1
    if midx < bodies.length
      bid = bodies[midx].to_i
    end

    saved_ci = @current_class_idx
    @current_class_idx = cci

    cname = @cls_names[cci]
    @block_counter = @block_counter + 1
    suffix = "_y" + @block_counter.to_s

    # For the method params and locals, create remapped names
    all_params = @cls_meth_params[cci].split("|")
    all_ptypes = @cls_meth_ptypes[cci].split("|")
    pnames = "".split(",")
    ptypes = "".split(",")
    if midx < all_params.length
      pnames = all_params[midx].split(",")
    end
    if midx < all_ptypes.length
      ptypes = all_ptypes[midx].split(",")
    end

    map_from = "".split(",")
    map_to = "".split(",")

    # Map self to the receiver expression
    map_from.push("_self_")
    map_to.push(rc)

    args_id = @nd_arguments[nid]
    arg_ids = []
    if args_id >= 0
      arg_ids = get_args(args_id)
    end

    k = 0
    while k < pnames.length
      pt = "int"
      if k < ptypes.length
        pt = ptypes[k]
      end
      tname = pnames[k] + suffix
      val = "0"
      if k < arg_ids.length
        val = compile_expr(arg_ids[k])
      end
      emit("  " + c_type(pt) + " lv_" + tname + " = " + val + ";")
      map_from.push(pnames[k])
      map_to.push(tname)
      declare_var(tname, pt)
      k = k + 1
    end

    # Declare function locals
    if bid >= 0
      flocals_n = "".split(",")
      flocals_t = "".split(",")
      scan_locals(bid, flocals_n, flocals_t, pnames)
      k = 0
      while k < flocals_n.length
        tname = flocals_n[k] + suffix
        emit("  " + c_type(flocals_t[k]) + " lv_" + tname + " = " + c_default_val(flocals_t[k]) + ";")
        map_from.push(flocals_n[k])
        map_to.push(tname)
        declare_var(tname, flocals_t[k])
        k = k + 1
      end
    end

    # Compile the method body inline with yield -> block body
    if bid >= 0
      stmts = get_stmts(bid)
      k = 0
      while k < stmts.length
        compile_stmt_with_block(stmts[k], blk, bp_names, map_from, map_to)
        k = k + 1
      end
    end

    @current_class_idx = saved_ci
  end

  def compile_each_with_yield_inline(nid, outer_blk, outer_bp_names, map_from, map_to)
    # An each call on an array inside an inlined yield function
    # The each block contains yield statements that should be replaced with outer block body
    recv = @nd_receiver[nid]
    recv_expr = compile_expr_remap(recv, map_from, map_to)
    rt = infer_type(recv)
    # If recv is remapped, get the actual type
    if @nd_type[recv] == "InstanceVariableReadNode"
      if @current_class_idx >= 0
        rt = cls_ivar_type(@current_class_idx, @nd_name[recv])
      end
    end

    inner_bp1 = get_block_param(nid, 0)
    if inner_bp1 == ""
      inner_bp1 = "_ex"
    end
    # The inner block param might collide with outer names, so remap it
    inner_bp_remapped = remap_local(inner_bp1, map_from, map_to)

    old = @in_loop
    @in_loop = 1
    tmp = new_temp

    if rt == "int_array"
      emit("  for (mrb_int " + tmp + " = 0; " + tmp + " < sp_IntArray_length(" + recv_expr + "); " + tmp + "++) {")
      emit("    lv_" + inner_bp_remapped + " = sp_IntArray_get(" + recv_expr + ", " + tmp + ");")
      @indent = @indent + 1
      # Compile inner block body, replacing yield with outer block body
      inner_blk = @nd_block[nid]
      if inner_blk >= 0
        ibody = @nd_body[inner_blk]
        if ibody >= 0
          istmts = get_stmts(ibody)
          sk = 0
          while sk < istmts.length
            # In the inner block, yield should be replaced with outer block body
            inner_nid = istmts[sk]
            if @nd_type[inner_nid] == "YieldNode"
              # yield x -> set outer bp from inner bp, then run outer block body
              yargs = @nd_arguments[inner_nid]
              if yargs >= 0
                yaids = get_args(yargs)
                yk = 0
                while yk < yaids.length
                  if yk < outer_bp_names.length
                    emit("  lv_" + outer_bp_names[yk] + " = " + compile_expr_remap(yaids[yk], map_from, map_to) + ";")
                  end
                  yk = yk + 1
                end
              end
              obody = @nd_body[outer_blk]
              if obody >= 0
                ostmts = get_stmts(obody)
                ok = 0
                while ok < ostmts.length
                  compile_stmt(ostmts[ok])
                  ok = ok + 1
                end
              end
            else
              compile_stmt_with_block(inner_nid, outer_blk, outer_bp_names, map_from, map_to)
            end
            sk = sk + 1
          end
        end
      end
      @indent = @indent - 1
      emit("  }")
    end
    @in_loop = old
  end

  def scan_captured_locals(nid, excludes, names, types)
    if nid < 0
      return
    end
    if @nd_type[nid] == "LocalVariableReadNode"
      lname = @nd_name[nid]
      if not_in(lname, excludes) == 1
        if not_in(lname, names) == 1
          names.push(lname)
          vt = find_var_type(lname)
          if vt == ""
            vt = "int"
          end
          types.push(vt)
        end
      end
    end
    if @nd_type[nid] == "LocalVariableWriteNode"
      lname = @nd_name[nid]
      if not_in(lname, excludes) == 1
        if not_in(lname, names) == 1
          names.push(lname)
          vt = find_var_type(lname)
          if vt == ""
            vt = "int"
          end
          types.push(vt)
        end
      end
    end
    # Recurse
    if @nd_body[nid] >= 0
      scan_captured_locals(@nd_body[nid], excludes, names, types)
    end
    stmts = parse_id_list(@nd_stmts[nid])
    k = 0
    while k < stmts.length
      scan_captured_locals(stmts[k], excludes, names, types)
      k = k + 1
    end
    if @nd_expression[nid] >= 0
      scan_captured_locals(@nd_expression[nid], excludes, names, types)
    end
    if @nd_predicate[nid] >= 0
      scan_captured_locals(@nd_predicate[nid], excludes, names, types)
    end
    if @nd_left[nid] >= 0
      scan_captured_locals(@nd_left[nid], excludes, names, types)
    end
    if @nd_right[nid] >= 0
      scan_captured_locals(@nd_right[nid], excludes, names, types)
    end
    if @nd_subsequent[nid] >= 0
      scan_captured_locals(@nd_subsequent[nid], excludes, names, types)
    end
    if @nd_else_clause[nid] >= 0
      scan_captured_locals(@nd_else_clause[nid], excludes, names, types)
    end
    if @nd_arguments[nid] >= 0
      scan_captured_locals(@nd_arguments[nid], excludes, names, types)
    end
    args = parse_id_list(@nd_args[nid])
    k = 0
    while k < args.length
      scan_captured_locals(args[k], excludes, names, types)
      k = k + 1
    end
    if @nd_receiver[nid] >= 0
      scan_captured_locals(@nd_receiver[nid], excludes, names, types)
    end
  end

  def compile_map_block(nid)
    @needs_int_array = 1
    @needs_gc = 1
    old = @in_loop
    @in_loop = 1
    rt = infer_type(@nd_receiver[nid])
    rc = compile_expr(@nd_receiver[nid])
    bp1 = get_block_param(nid, 0)
    if bp1 == ""
      bp1 = "_x"
    end
    tmp_arr = new_temp
    tmp_i = new_temp
    if rt == "int_array"
      emit("  sp_IntArray *" + tmp_arr + " = sp_IntArray_new();")
      emit("  for (mrb_int " + tmp_i + " = 0; " + tmp_i + " < sp_IntArray_length(" + rc + "); " + tmp_i + "++) {")
      emit("    lv_" + bp1 + " = sp_IntArray_get(" + rc + ", " + tmp_i + ");")
      @indent = @indent + 1
      blk = @nd_block[nid]
      if blk >= 0
        body = @nd_body[blk]
        if body >= 0
          stmts = get_stmts(body)
          if stmts.length > 0
            last = stmts[stmts.length - 1]
            val = compile_expr(last)
            emit("  sp_IntArray_push(" + tmp_arr + ", " + val + ");")
          end
        end
      end
      @indent = @indent - 1
      emit("  }")
    end
    if rt == "str_array"
      @needs_str_array = 1
      emit("  sp_StrArray *" + tmp_arr + " = sp_StrArray_new();")
      emit("  for (mrb_int " + tmp_i + " = 0; " + tmp_i + " < sp_StrArray_length(" + rc + "); " + tmp_i + "++) {")
      emit("    lv_" + bp1 + " = sp_StrArray_get(" + rc + ", " + tmp_i + ");")
      @indent = @indent + 1
      blk = @nd_block[nid]
      if blk >= 0
        body = @nd_body[blk]
        if body >= 0
          stmts = get_stmts(body)
          if stmts.length > 0
            last = stmts[stmts.length - 1]
            val = compile_expr(last)
            emit("  sp_StrArray_push(" + tmp_arr + ", " + val + ");")
          end
        end
      end
      @indent = @indent - 1
      emit("  }")
    end
    @in_loop = old
  end

  def compile_select_block(nid)
    @needs_int_array = 1
    @needs_gc = 1
    old = @in_loop
    @in_loop = 1
    rt = infer_type(@nd_receiver[nid])
    rc = compile_expr(@nd_receiver[nid])
    bp1 = get_block_param(nid, 0)
    if bp1 == ""
      bp1 = "_x"
    end
    tmp_arr = new_temp
    tmp_i = new_temp
    if rt == "int_array"
      emit("  sp_IntArray *" + tmp_arr + " = sp_IntArray_new();")
      emit("  for (mrb_int " + tmp_i + " = 0; " + tmp_i + " < sp_IntArray_length(" + rc + "); " + tmp_i + "++) {")
      emit("    lv_" + bp1 + " = sp_IntArray_get(" + rc + ", " + tmp_i + ");")
      @indent = @indent + 1
      blk = @nd_block[nid]
      if blk >= 0
        body = @nd_body[blk]
        if body >= 0
          stmts = get_stmts(body)
          if stmts.length > 0
            last = stmts[stmts.length - 1]
            cond = compile_expr(last)
            emit("  if (" + cond + ") sp_IntArray_push(" + tmp_arr + ", lv_" + bp1 + ");")
          end
        end
      end
      @indent = @indent - 1
      emit("  }")
    end
    @in_loop = old
  end

  def compile_stmts_body(nid)
    if nid < 0
      return
    end
    stmts = get_stmts(nid)
    k = 0
    while k < stmts.length
      compile_stmt(stmts[k])
      k = k + 1
    end
  end

  def compile_body_return(body_id, return_type)
    if body_id < 0
      if return_type != "void"
        emit("  return " + c_default_val(return_type) + ";")
      end
      return
    end
    stmts = get_stmts(body_id)
    if stmts.length == 0
      if return_type != "void"
        emit("  return " + c_default_val(return_type) + ";")
      end
      return
    end
    # All but last
    i = 0
    while i < stmts.length - 1
      compile_stmt(stmts[i])
      i = i + 1
    end
    last = stmts[stmts.length - 1]
    if @nd_type[last] == "ReturnNode"
      compile_return_stmt(last)
      return
    end
    if @nd_type[last] == "IfNode"
      compile_if_return(last, return_type)
      return
    end
    if @nd_type[last] == "CaseNode"
      compile_case_return(last, return_type)
      return
    end
    if @nd_type[last] == "WhileNode"
      compile_while_stmt(last)
      if return_type != "void"
        emit("  return " + c_default_val(return_type) + ";")
      end
      return
    end
    if @nd_type[last] == "YieldNode"
      compile_yield_stmt(last)
      if return_type != "void"
        emit("  return " + c_default_val(return_type) + ";")
      end
      return
    end
    if @nd_type[last] == "BeginNode"
      compile_begin_stmt(last)
      if return_type != "void"
        emit("  return " + c_default_val(return_type) + ";")
      end
      return
    end
    if @nd_type[last] == "CaseMatchNode"
      compile_case_match_return(last, return_type)
      return
    end
    # If last statement is a CallNode with a block, handle map/select as expressions
    if @nd_type[last] == "CallNode"
      if @nd_block[last] >= 0
        lmname = @nd_name[last]
        if lmname == "map"
          if return_type != "void"
            val = compile_map_expr(last)
            emit("  return " + val + ";")
            return
          end
        end
        if lmname == "select"
          if return_type != "void"
            val = compile_select_expr(last)
            emit("  return " + val + ";")
            return
          end
        end
        compile_stmt(last)
        if return_type != "void"
          emit("  return " + c_default_val(return_type) + ";")
        end
        return
      end
    end
    # For statement-like nodes as last expression, compile as stmt then return default
    lt = @nd_type[last]
    if lt == "InstanceVariableWriteNode"
      compile_stmt(last)
      if return_type != "void"
        emit("  return " + c_default_val(return_type) + ";")
      end
      return
    end
    if lt == "InstanceVariableOperatorWriteNode"
      compile_stmt(last)
      if return_type != "void"
        emit("  return " + c_default_val(return_type) + ";")
      end
      return
    end
    if lt == "LocalVariableWriteNode"
      compile_stmt(last)
      if return_type != "void"
        emit("  return lv_" + @nd_name[last] + ";")
      end
      return
    end
    if lt == "LocalVariableOperatorWriteNode"
      compile_stmt(last)
      if return_type != "void"
        emit("  return lv_" + @nd_name[last] + ";")
      end
      return
    end
    if lt == "MultiWriteNode"
      compile_stmt(last)
      if return_type != "void"
        emit("  return " + c_default_val(return_type) + ";")
      end
      return
    end
    if return_type != "void"
      emit("  return " + compile_expr(last) + ";")
    else
      compile_stmt(last)
    end
    return
  end

  def compile_if_return(nid, rt)
    cond = compile_expr(@nd_predicate[nid])
    emit("  if (" + cond + ") {")
    @indent = @indent + 1
    body = @nd_body[nid]
    if body >= 0
      compile_body_return(body, rt)
    else
      if rt != "void"
        emit("  return " + c_default_val(rt) + ";")
      end
    end
    @indent = @indent - 1
    sub = @nd_subsequent[nid]
    if sub >= 0
      if @nd_type[sub] == "ElseNode"
        emit("  } else {")
        @indent = @indent + 1
        eb = @nd_body[sub]
        if eb >= 0
          compile_body_return(eb, rt)
        else
          if rt != "void"
            emit("  return " + c_default_val(rt) + ";")
          end
        end
        @indent = @indent - 1
      else
        emit("  } else")
        compile_if_return(sub, rt)
        return
      end
    else
      if rt != "void"
        emit("  } else {")
        emit("    return " + c_default_val(rt) + ";")
      end
    end
    emit("  }")
  end

  def compile_case_match_return(nid, rt)
    pred = @nd_predicate[nid]
    pred_type = infer_type(pred)
    pred_val = compile_expr(pred)
    tmp = new_temp
    if pred_type == "poly"
      emit("  sp_RbVal " + tmp + " = " + pred_val + ";")
    else
      if pred_type == "string"
        emit("  const char *" + tmp + " = " + pred_val + ";")
      else
        if pred_type == "float"
          emit("  mrb_float " + tmp + " = " + pred_val + ";")
        else
          emit("  mrb_int " + tmp + " = " + pred_val + ";")
        end
      end
    end
    conds = parse_id_list(@nd_conditions[nid])
    k = 0
    while k < conds.length
      inid = conds[k]
      if @nd_type[inid] == "InNode"
        kw = "if"
        if k > 0
          kw = "} else if"
        end
        pat = @nd_pattern[inid]
        cond_str = compile_in_pattern(pat, tmp, pred_type)
        emit("  " + kw + " (" + cond_str + ") {")
        @indent = @indent + 1
        compile_body_return(@nd_body[inid], rt)
        @indent = @indent - 1
      end
      k = k + 1
    end
    ec = @nd_else_clause[nid]
    if ec >= 0
      emit("  } else {")
      @indent = @indent + 1
      compile_body_return(@nd_body[ec], rt)
      @indent = @indent - 1
    end
    if conds.length > 0
      emit("  }")
    end
  end

  def compile_case_return(nid, rt)
    pred = @nd_predicate[nid]
    if pred >= 0
      pred_type = infer_type(pred)
      pred_val = compile_expr(pred)
      tmp = new_temp
      if pred_type == "string"
        emit("  const char *" + tmp + " = " + pred_val + ";")
      else
        emit("  mrb_int " + tmp + " = " + pred_val + ";")
      end
      conds = parse_id_list(@nd_conditions[nid])
      k = 0
      while k < conds.length
        wid = conds[k]
        if @nd_type[wid] == "WhenNode"
          kw = "if"
          if k > 0
            kw = "} else if"
          end
          cond_str = compile_when_conds(wid, tmp, pred_type)
          emit("  " + kw + " (" + cond_str + ") {")
          @indent = @indent + 1
          compile_body_return(@nd_body[wid], rt)
          @indent = @indent - 1
        end
        k = k + 1
      end
    else
      conds = parse_id_list(@nd_conditions[nid])
      k = 0
      while k < conds.length
        wid = conds[k]
        kw = "if"
        if k > 0
          kw = "} else if"
        end
        wconds = parse_id_list(@nd_conditions[wid])
        cexpr = "0"
        if wconds.length > 0
          cexpr = compile_expr(wconds[0])
        end
        emit("  " + kw + " (" + cexpr + ") {")
        @indent = @indent + 1
        compile_body_return(@nd_body[wid], rt)
        @indent = @indent - 1
        k = k + 1
      end
    end
    ec = @nd_else_clause[nid]
    if ec >= 0
      emit("  } else {")
      @indent = @indent + 1
      compile_body_return(@nd_body[ec], rt)
      @indent = @indent - 1
    end
    emit("  }")
  end
end

# ---- Main ----
ast_file = ARGV[0]
out_file = ARGV[1]

if ast_file == nil
  $stderr.puts "Usage: ruby spinel_codegen.rb ast.txt output.c"
  exit(1)
end

data = File.read(ast_file)
compiler = Compiler.new
compiler.read_text_ast(data)
compiler.compile

if out_file != nil
  File.write(out_file, compiler.out)
else
  print compiler.out
end
