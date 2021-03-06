class YARD::Handlers::Ruby::ClassHandler < YARD::Handlers::Ruby::Base
  namespace_only
  handles :class, :sclass
  
  process do
    if statement.type == :class
      classname = statement[0].source
      superclass = parse_superclass(statement[1])
      undocsuper = statement[1] && superclass.nil?

      klass = register ClassObject.new(namespace, classname) do |o|
        o.superclass = superclass if superclass
        o.superclass.type = :class if o.superclass.is_a?(Proxy)
      end
      parse_block(statement[2], namespace: klass)
       
      if undocsuper
        raise YARD::Parser::UndocumentableError, 'superclass (class was added without superclass)'
      end
    elsif statement.type == :sclass
      if statement[0] == s(:var_ref, s(:kw, "self"))
        parse_block(statement[1], namespace: namespace, scope: :class)
      else
        classname = statement[0].source
        proxy = Proxy.new(namespace, classname)

        # Allow constants to reference class names
        if ConstantObject === proxy
          if proxy.value =~ /\A#{NAMESPACEMATCH}\Z/
            proxy = Proxy.new(namespace, proxy.value)
          else
            raise YARD::Parser::UndocumentableError, "constant class reference '#{classname}'"
          end
        end

        if classname[0,1] =~ /[A-Z]/
          register ClassObject.new(namespace, classname) if Proxy === proxy
          parse_block(statement[1], namespace: proxy, scope: :class)
        else
          raise YARD::Parser::UndocumentableError, "class '#{classname}'"
        end
      end
    else
      sig_end = (statement[1] ? statement[1].source_end : statement[0].source_end) - statement.source_start
      raise YARD::Parser::UndocumentableError, "class: #{statement.source[0..sig_end]}"
    end
  end
  
  private
  
  def parse_superclass(superclass)
    return nil unless superclass
    
    case superclass.type
    when :var_ref
      return superclass.source if superclass.first.type == :const
    when :const, :const_ref, :const_path_ref, :top_const_ref
      return superclass.source
    when :fcall, :command
      methname = superclass.method_name.source
      if methname == "DelegateClass"
        return superclass.parameters.first.source
      elsif superclass.method_name.type == :const
        return methname
      end
    when :call, :command_call
      cname = superclass.namespace.source
      if cname =~ /^O?Struct$/ && superclass.method_name(true) == :new
        return cname
      end
    end
    nil
  end
end