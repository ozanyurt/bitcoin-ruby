require 'bitcoin'

class Bitcoin::Script

  OP_1           = 81
  OP_TRUE        = 81
  OP_0           = 0
  OP_FALSE       = 0
  OP_PUSHDATA0   = 0
  OP_PUSHDATA1   = 76
  OP_PUSHDATA2   = 77
  OP_PUSHDATA4   = 78
  OP_NOP         = 97
  OP_DUP         = 118
  OP_HASH160     = 169
  OP_EQUAL       = 135
  OP_VERIFY      = 105
  OP_EQUALVERIFY = 136
  OP_CHECKSIG    = 172
  OP_CHECKSIGVERIFY      = 173
  OP_CHECKMULTISIG       = 174
  OP_CHECKMULTISIGVERIFY = 175
  OP_TOALTSTACK   = 107
  OP_FROMALTSTACK = 108
  OP_TUCK         = 125
  OP_SWAP         = 124
  OP_BOOLAND      = 154
  OP_ADD          = 147
  OP_SUB          = 148
  OP_GREATERTHANOREQUAL = 162
  OP_DROP         = 117
  OP_HASH256      = 170
  OP_SHA256       = 168
  OP_SHA1         = 167
  OP_RIPEMD160    = 166
  OP_NOP1         = 176
  OP_NOP2         = 177
  OP_NOP3         = 178
  OP_NOP4         = 179
  OP_NOP5         = 180
  OP_NOP6         = 181
  OP_NOP7         = 182
  OP_NOP8         = 183
  OP_NOP9         = 184
  OP_NOP10        = 185
  OP_CODESEPARATOR = 171
  OP_MIN          = 163
  OP_MAX          = 164
  OP_2OVER        = 112
  OP_2SWAP        = 114
  OP_IFDUP        = 115
  OP_DEPTH        = 116
  OP_1NEGATE      = 79
  OP_WITHIN         = 165
  OP_NUMEQUAL       = 156
  OP_NUMEQUALVERIFY = 157
  OP_LESSTHAN     = 159
  OP_LESSTHANOREQUAL = 161
  OP_GREATERTHAN  = 160
  OP_NOT            = 145
  OP_0NOTEQUAL = 146
  OP_ABS = 144
  OP_1ADD = 139
  OP_1SUB = 140
  OP_NEGATE = 143
  OP_BOOLOR = 155
  OP_NUMNOTEQUAL = 158
  OP_RETURN = 106
  OP_OVER = 120
  OP_IF = 99
  OP_NOTIF = 100
  OP_ELSE = 103
  OP_ENDIF = 104
  OP_PICK = 121
  OP_SIZE = 130
  OP_VER = 98
  OP_ROLL = 122
  OP_ROT = 123
  OP_2DROP = 109
  OP_2DUP = 110
  OP_3DUP = 111
  OP_NIP = 119

  OP_CAT = 126
  OP_SUBSTR = 127
  OP_LEFT = 128
  OP_RIGHT = 129
  OP_INVERT = 131
  OP_AND = 132
  OP_OR = 133
  OP_XOR = 134
  OP_2MUL = 141
  OP_2DIV = 142
  OP_MUL = 149
  OP_DIV = 150
  OP_MOD = 151
  OP_LSHIFT = 152
  OP_RSHIFT = 153


  OPCODES = Hash[*constants.grep(/^OP_/).map{|i| [const_get(i), i.to_s] }.flatten]
  OPCODES[0] = "0"
  OPCODES[81] = "1"

  OPCODES_ALIAS = {
    "OP_TRUE"  => OP_1,
    "OP_FALSE" => OP_0,
    "OP_EVAL" => OP_NOP1,
    #"OP_NOP2" => OP_CHECKHASHVERIFY,
    "OP_CHECKHASHVERIFY" => OP_NOP2,
  }

  DISABLED_OPCODES = [
    OP_CAT, OP_SUBSTR, OP_LEFT, OP_RIGHT, OP_INVERT,
    OP_AND, OP_OR, OP_XOR, OP_2MUL, OP_2DIV, OP_MUL,
    OP_DIV, OP_MOD, OP_LSHIFT, OP_RSHIFT
  ]

  OP_CHECKHASHVERIFY = 177 # disabled

  OP_2_16 = (82..96).to_a

  attr_reader :raw, :chunks, :debug

  # create a new script. +bytes+ is typically input_script + output_script
  def initialize(bytes, offset=0)
    @raw = bytes
    @stack, @stack_alt, @exec_stack = [], [], []
    @chunks = parse(bytes, offset)
    @do_exec = true
  end

  class ::String
    attr_accessor :bitcoin_pushdata
    attr_accessor :bitcoin_pushdata_length
  end

  # parse raw script
  def parse(bytes, offset=0)
    program = bytes.unpack("C*")
    chunks = []
    until program.empty?
      opcode = program.shift(1)[0]
      if opcode >= 0xf0 and program[0]
        opcode = (opcode << 8) | program.shift(1)[0]
      end

      if (opcode > 0) && (opcode < OP_PUSHDATA1)
        len, tmp = opcode, program[0]
        chunks << program.shift(len).pack("C*")

        # 0x16 = 22 due to OP_2_16 from_string parsing
        if len == 1 && tmp <= 22
          chunks.last.bitcoin_pushdata = OP_PUSHDATA0
          chunks.last.bitcoin_pushdata_length = len
        end
      elsif (opcode == OP_PUSHDATA1)
        len = program.shift(1)[0]
        chunks << program.shift(len).pack("C*")

        unless len > OP_PUSHDATA1 && len <= 0xff
          chunks.last.bitcoin_pushdata = OP_PUSHDATA1
          chunks.last.bitcoin_pushdata_length = len
        end
      elsif (opcode == OP_PUSHDATA2)
        len = program.shift(2).pack("C*").unpack("v")[0]
        chunks << program.shift(len).pack("C*")

        unless len > 0xff && len <= 0xffff
          chunks.last.bitcoin_pushdata = OP_PUSHDATA2
          chunks.last.bitcoin_pushdata_length = len
        end
      elsif (opcode == OP_PUSHDATA4)
        len = program.shift(4).pack("C*").unpack("V")[0]
        chunks << program.shift(len).pack("C*")

        unless len > 0xffff # && len <= 0xffffffff
          chunks.last.bitcoin_pushdata = OP_PUSHDATA4
          chunks.last.bitcoin_pushdata_length = len
        end
      else
        chunks << opcode
      end
    end
    chunks
  end

  # string representation of the script
  def to_string(chunks=nil)
    (chunks || @chunks).map{|i|
      case i
      when Fixnum
        case i
        when *OPCODES.keys;          OPCODES[i]
        when *OP_2_16;               (OP_2_16.index(i)+2).to_s
        #when *OP_2_16;               "OP_" + (OP_2_16.index(i)+2).to_s
        else "(opcode-#{i})"
        end
      when String
        if i.bitcoin_pushdata
          "#{i.bitcoin_pushdata}:#{i.bitcoin_pushdata_length}:".force_encoding('binary') + i.unpack("H*")[0]
        #elsif i.bytesize == 1
        #  i.unpack("c")[0]
        else
          i.unpack("H*")[0]
        end
      end
    }.join(" ")
  end

  def to_binary(chunks=nil)
    (chunks || @chunks).map{|chunk|
      case chunk
      when Fixnum; [chunk].pack("C*")
      when String; self.class.pack_pushdata(chunk)
      end
    }.join
  end
  alias :to_payload :to_binary

  def self.pack_pushdata(data)
    size = data.bytesize

    if data.bitcoin_pushdata
      size = data.bitcoin_pushdata_length
      pack_pushdata_align(data.bitcoin_pushdata, size, data)
    else
      head = if size < OP_PUSHDATA1
               [size].pack("C")
             elsif size <= 0xff
               [OP_PUSHDATA1, size].pack("CC")
             elsif size <= 0xffff
               [OP_PUSHDATA2, size].pack("Cv")
             #elsif size <= 0xffffffff
             else
               [OP_PUSHDATA4, size].pack("CV")
             end
      head + data
    end
  end

  def self.pack_pushdata_align(pushdata, len, data)
    case pushdata
    when OP_PUSHDATA1
      [OP_PUSHDATA1, len].pack("CC") + data
    when OP_PUSHDATA2
      [OP_PUSHDATA2, len].pack("Cv") + data
    when OP_PUSHDATA4
      [OP_PUSHDATA4, len].pack("CV") + data
    else # OP_PUSHDATA0
      [len].pack("C") + data
    end
  end

  # script object of a string representation
  def self.from_string(script_string)
    new(binary_from_string(script_string))
  end

  class ScriptOpcodeError < StandardError; end

  # raw script binary of a string representation
  def self.binary_from_string(script_string)
    script_string.split(" ").map{|i|
      case i
      when /^OP_PUSHDATA[124]$/;     # skip
      when *OPCODES.values;          OPCODES.find{|k,v| v == i }.first
      when *OPCODES_ALIAS.keys;      OPCODES_ALIAS.find{|k,v| k == i }.last
      when /^([2-9]|1[0-6])$/;       OP_2_16[$1.to_i-2]
      when /^OP_([2-9]|1[0-6])$/;    OP_2_16[$1.to_i-2]
      when /\(opcode\-(\d+)\)/;      $1.to_i
      when /^(\d+)\)/;               $1.to_i # fix invalid opcode parsing
      when /^\(opcode$/;             # skip  # fix invalid opcode parsing
      when /OP_(.+)$/;               raise ScriptOpcodeError, "#{i} not defined!"
      when /(\d+):(\d+):(.+)?/
        pushdata, len, data = $1.to_i, $2.to_i, $3
        pack_pushdata_align(pushdata, len, [data].pack("H*"))
      #when /^(-)?([0-9][0-9]?|1[0-1][0-9]|12[0-8])$/
      #  negative, number = $1, $2.to_i
      #  data = [ negative ? -number : number ].pack("c")
      #  pack_pushdata(data)
      else 
        data = [i].pack("H*")
        pack_pushdata(data)
      end
    }.map{|i|
      i.is_a?(Fixnum) ? [OpenSSL::BN.new(i.to_s,10).to_hex].pack("H*") : i
    }.join
  end

  def invalid?
    @script_invalid ||= false
  end

  # run the script. +check_callback+ is called for OP_CHECKSIG operations
  def run(block_timestamp=Time.now.to_i, &check_callback)
    #p [to_string, block_timestamp, is_p2sh?]
    @script_invalid = true if @raw.bytesize > 10_000

    if block_timestamp >= 1333238400 # Pay to Script Hash (BIP 0016)
      return pay_to_script_hash(check_callback)  if is_p2sh?
    end

    @debug = []
    @chunks.each{|chunk|
      break if invalid?

      @debug << @stack.map{|i| i.unpack("H*") rescue i}
      @do_exec = @exec_stack.count(false) == 0 ? true : false
      #p [@stack, @do_exec]
      
      case chunk
      when Fixnum
        next unless (@do_exec || (OP_IF <= chunk && chunk <= OP_ENDIF))

        case chunk
        when *DISABLED_OPCODES
          @script_invalid = true
          @debug << "DISABLED_#{OPCODES[chunk]}"
        when *OPCODES_METHOD.keys
          m = method( n=OPCODES_METHOD[chunk] )
          @debug << n.to_s.upcase
          (m.arity == 1) ? m.call(check_callback) : m.call  # invoke opcode method
        when *OP_2_16
          @stack << OP_2_16.index(chunk) + 2
          @debug << "OP_#{chunk-80}"
        else
          name = OPCODES[chunk] || chunk
          raise "opcode #{name} unkown or not implemented"
        end
      when String
        if @do_exec
          @debug << "PUSH DATA #{chunk.unpack("H*")[0]}"
          @stack << chunk
        end
      end
    }
    @debug << @stack.map{|i| i.unpack("H*") rescue i } #if @do_exec

    if @script_invalid
      @stack << 0
      @debug << "INVALID TRANSACTION"
    end

    @debug << "RESULT"
    return false if @stack.empty?
    return false if [0, ''].include?(@stack.pop)
    true
  end

  def invalid
    @script_invalid = true; nil
  end

  def codehash_script(opcode)
    # CScript scriptCode(pbegincodehash, pend);
    script    = to_string(@chunks[(@codehash_start||0)...@chunks.size-@chunks.reverse.index(opcode)])
    checkhash = Bitcoin.hash160(Bitcoin::Script.binary_from_string(script).unpack("H*")[0])
    [script, checkhash]
  end

  def self.drop_signatures(script_pubkey, drop_signatures)
    script = new(script_pubkey).to_string.split(" ").delete_if{|c| drop_signatures.include?(c) }.join(" ")
    script_pubkey = binary_from_string(script)
  end

  # pay_to_script_hash: https://en.bitcoin.it/wiki/BIP_0016
  #
  # <sig> {<pub> OP_CHECKSIG} | OP_HASH160 <script_hash> OP_EQUAL
  def pay_to_script_hash(check_callback)
    return false if @chunks.size < 4
    *rest, script, _, script_hash, _ = @chunks

    return false unless [script, script_hash].all?{|i| i.is_a?(String) }
    return false unless Bitcoin.hash160(script.unpack("H*")[0]) == script_hash.unpack("H*")[0]
    rest.delete_at(0) if rest[0] == 0

    script = self.class.new(to_binary(rest) + script).inner_p2sh!
    result = script.run(&check_callback)
    @debug = script.debug
    result
  end

  def inner_p2sh!; @inner_p2sh = true; self; end
  def inner_p2sh?; @inner_p2sh; end

  def is_pay_to_script_hash?
    return false  unless @chunks[-2].is_a?(String)
    @chunks.size >= 3 && @chunks[-3] == OP_HASH160 &&
      @chunks[-2].bytesize == 20 && @chunks[-1] == OP_EQUAL
  end
  alias :is_p2sh? :is_pay_to_script_hash?

  # check if script is in one of the recognized standard formats
  def is_standard?
    is_pubkey? || is_hash160? || is_multisig? || is_p2sh?
  end

  # is this a pubkey tx
  def is_pubkey?
    return false if @chunks.size != 2
    (@chunks[1] == OP_CHECKSIG) && @chunks[0].size > 1
  end
  alias :is_send_to_ip? :is_pubkey?

  # is this a hash160 (address) tx
  def is_hash160?
    return false  if @chunks.size != 5
    (@chunks[0..1] + @chunks[-2..-1]) ==
      [OP_DUP, OP_HASH160, OP_EQUALVERIFY, OP_CHECKSIG] &&
      @chunks[2].is_a?(String) && @chunks[2].bytesize == 20
  end

  # is this a multisig tx
  def is_multisig?
    return false  if @chunks.size > 6 || @chunks.size < 4
    @chunks[-1] == OP_CHECKMULTISIG
  end

  # get type of this tx
  def type
    if is_hash160?;     :hash160
    elsif is_pubkey?;   :pubkey
    elsif is_multisig?; :multisig
    elsif is_p2sh?;     :p2sh
    else;               :unknown
    end
  end

  # get the public key for this pubkey script
  def get_pubkey
    return @chunks[0].unpack("H*")[0] if @chunks.size == 1
    is_pubkey? ? @chunks[0].unpack("H*")[0] : nil
  end

  # get the pubkey address for this pubkey script
  def get_pubkey_address
    Bitcoin.pubkey_to_address(get_pubkey)
  end

  # get the hash160 for this hash160 or pubkey script
  def get_hash160
    return @chunks[2..-3][0].unpack("H*")[0]  if is_hash160?
    return Bitcoin.hash160(get_pubkey)        if is_pubkey?
  end

  # get the hash160 address for this hash160 script
  def get_hash160_address
    Bitcoin.hash160_to_address(get_hash160)
  end

  # get the public keys for this multisig script
  def get_multisig_pubkeys
    1.upto(@chunks[-2] - 80).map {|i| @chunks[i]}
  end

  # get the pubkey addresses for this multisig script
  def get_multisig_addresses
    get_multisig_pubkeys.map{|pub|
      begin
        Bitcoin::Key.new(nil, pub.unpack("H*")[0]).addr
      rescue OpenSSL::PKey::ECError, OpenSSL::PKey::EC::Point::Error
      end
    }.compact
  end

  # get all addresses this script corresponds to (if possible)
  def get_addresses
    return [get_pubkey_address]    if is_pubkey?
    return [get_hash160_address]   if is_hash160?
    return get_multisig_addresses  if is_multisig?
    []
  end

  # get single address, or first for multisig script
  def get_address
    addrs = get_addresses
    addrs.is_a?(Array) ? addrs[0] : addrs
  end

  # generate pubkey tx script for given +pubkey+
  def self.to_pubkey_script(pubkey)
    pk = [pubkey].pack("H*")
    [[pk.bytesize].pack("C"), pk, "\xAC"].join
  end

  # generate hash160 tx for given +address+
  def self.to_hash160_script(hash160)
    return nil  unless hash160
    #  DUP   HASH160  length  hash160    EQUALVERIFY  CHECKSIG
    [ ["76", "a9",    "14",   hash160,   "88",        "ac"].join ].pack("H*")
  end

  def self.to_p2sh_script(p2sh)
    return nil  unless p2sh
    # HASH160  length  hash  EQUAL
    [ ["a9",   "14",   p2sh, "87"].join ].pack("H*")
  end

  def self.to_address_script(address)
    hash160 = Bitcoin.hash160_from_address(address)
    case Bitcoin.address_type(address)
    when :hash160; to_hash160_script(hash160)
    when :p2sh;    to_p2sh_script(hash160)
    end
  end

  # generate multisig tx for given +pubkeys+, expecting +m+ signatures
  def self.to_multisig_script(m, *pubkeys)
    pubs = pubkeys.map{|pk|p=[pk].pack("H*"); [p.bytesize].pack("C") + p}
    [ [80 + m.to_i].pack("C"), *pubs, [80 + pubs.size].pack("C"), "\xAE"].join
  end

  # generate pubkey script sig for given +signature+ and +pubkey+
  def self.to_pubkey_script_sig(signature, pubkey)
    hash_type = "\x01"
    #pubkey = [pubkey].pack("H*") if pubkey.bytesize != 65

    case pubkey[0]
    when "\x04"
      expected_size = 65
    when "\x02", "\x03"
      expected_size = 33
    end

    if !expected_size || pubkey.bytesize != expected_size
      raise "pubkey is not in binary form"
    end

    [ [signature.bytesize+1].pack("C"), signature, hash_type, [pubkey.bytesize].pack("C"), pubkey ].join
  end

  # alias for #to_pubkey_script_sig
  def self.to_signature_pubkey_script(*a)
    to_pubkey_script_sig(*a)
  end

  def self.to_multisig_script_sig(*sigs)
    from_string("0 #{sigs.map{|s|s.unpack('H*')[0]}.join(' ')}").raw
  end

  def get_signatures_required
    return false unless is_multisig?
    @chunks[0] - 80
  end

  ## OPCODES

  # Does nothing
  def op_nop; end
  def op_nop1; end
  def op_nop2; end
  def op_nop3; end
  def op_nop4; end
  def op_nop5; end
  def op_nop6; end
  def op_nop7; end
  def op_nop8; end
  def op_nop9; end
  def op_nop10; end

  # Duplicates the top stack item.
  def op_dup
    @stack << (@stack[-1].dup rescue @stack[-1])
  end

  # The input is hashed using SHA-256.
  def op_sha256
    buf = @stack.pop
    @stack << Digest::SHA256.digest(buf)
  end

  # The input is hashed using SHA-1.
  def op_sha1
    buf = @stack.pop
    @stack << Digest::SHA1.digest(buf)
  end

  # The input is hashed twice: first with SHA-256 and then with RIPEMD-160.
  def op_hash160
    buf = @stack.pop
    @stack << Digest::RMD160.digest(Digest::SHA256.digest(buf))
  end

  # The input is hashed using RIPEMD-160.
  def op_ripemd160
    buf = @stack.pop
    @stack << Digest::RMD160.digest(buf)
  end

  # The input is hashed two times with SHA-256.
  def op_hash256
    buf = @stack.pop
    @stack << Digest::SHA256.digest(Digest::SHA256.digest(buf))
  end

  # Puts the input onto the top of the alt stack. Removes it from the main stack.
  def op_toaltstack
    @stack_alt << @stack.pop
  end

  # Puts the input onto the top of the main stack. Removes it from the alt stack.
  def op_fromaltstack
    @stack << @stack_alt.pop
  end

  # The item at the top of the stack is copied and inserted before the second-to-top item.
  def op_tuck
    @stack[-2..-1] = [ @stack[-1], *@stack[-2..-1] ]
  end

  # The top two items on the stack are swapped.
  def op_swap
    @stack[-2..-1] = @stack[-2..-1].reverse
  end

  # If both a and b are not 0, the output is 1. Otherwise 0.
  def op_booland
    a, b = pop_int(2)
    @stack << (![a,b].any?{|n| n == 0 } ? 1 : 0)
  end

  # If a or b is not 0, the output is 1. Otherwise 0.
  def op_boolor
    a, b = pop_int(2)
    @stack << ( (a != 0 || b != 0) ? 1 : 0 )
  end

  # a is added to b.
  def op_add
    a, b = pop_int(2)
    @stack << a + b
  end

  # b is subtracted from a.
  def op_sub
    a, b = pop_int(2)
    @stack << a - b
  end

  # Returns 1 if a is less than b, 0 otherwise.
  def op_lessthan
    a, b = pop_int(2)
    @stack << (a < b ? 1 : 0)
  end

  # Returns 1 if a is less than or equal to b, 0 otherwise.
  def op_lessthanorequal
    a, b = pop_int(2)
    @stack << (a <= b ? 1 : 0)
  end

  # Returns 1 if a is greater than b, 0 otherwise.
  def op_greaterthan
    a, b = pop_int(2)
    @stack << (a > b ? 1 : 0)
  end

  # Returns 1 if a is greater than or equal to b, 0 otherwise.
  def op_greaterthanorequal
    a, b = pop_int(2)
    @stack << (a >= b ? 1 : 0)
  end

  # If the input is 0 or 1, it is flipped. Otherwise the output will be 0.
  def op_not
    a = pop_int
    @stack << (a == 0 ? 1 : 0)
  end

  def op_0notequal
    a = pop_int
    @stack << (a != 0 ? 1 : 0)
  end

  # The input is made positive.
  def op_abs
    a = pop_int
    @stack << a.abs
  end

  # The input is divided by 2. Currently disabled.
  def op_2div
    a = pop_int
    @stack << (a >> 1)
  end

  # The input is multiplied by 2. Currently disabled.
  def op_2mul
    a = pop_int
    @stack << (a << 1)
  end

  # 1 is added to the input.
  def op_1add
    a = pop_int
    @stack << (a + 1)
  end

  def op_1sub
    a = pop_int
    @stack << (a - 1)
  end

  # The sign of the input is flipped.
  def op_negate
    a = pop_int
    @stack << -a
  end

  # Removes the top stack item.
  def op_drop
    @stack.pop
  end

  # Returns 1 if the inputs are exactly equal, 0 otherwise.
  def op_equal
    #a, b = @stack.pop(2)
    a, b = pop_int(2)
    @stack << (a == b ? 1 : 0)
  end

  # Marks transaction as invalid if top stack value is not true. True is removed, but false is not.
  def op_verify
    res = @stack.pop
    if res == 0
      @stack << res
      @script_invalid = true # raise 'transaction invalid' ?
    else
      @script_invalid = false
    end
  end

  # Same as OP_EQUAL, but runs OP_VERIFY afterward.
  def op_equalverify
    op_equal; op_verify
  end

  # An empty array of bytes is pushed onto the stack.
  def op_0
    @stack << "" # []
  end

  # The number 1 is pushed onto the stack. Same as OP_TRUE
  def op_1
    @stack << 1
  end

  # Returns the smaller of a and b.
  def op_min
    @stack << pop_int(2).min
  end

  # Returns the larger of a and b.
  def op_max
    @stack << pop_int(2).max
  end

  # Copies the pair of items two spaces back in the stack to the front.
  def op_2over
    @stack << @stack[-4]
    @stack << @stack[-4]
  end

  # Swaps the top two pairs of items.
  def op_2swap
    p1 = @stack.pop(2)
    p2 = @stack.pop(2)
    @stack += p1 += p2
  end

  # If the input is true, duplicate it.
  def op_ifdup
    if cast_to_bignum(@stack.last) != 0
      @stack << @stack.last
    end
  end

  # The number -1 is pushed onto the stack.
  def op_1negate
    @stack << -1
  end
  
  # Puts the number of stack items onto the stack.
  def op_depth
    @stack << @stack.size
  end

  # Returns 1 if x is within the specified range (left-inclusive), 0 otherwise.
  def op_within
    bn1, bn2, bn3 = pop_int(3)
    @stack << ( (bn2 <= bn1 && bn1 < bn3) ? 1 : 0 )
  end

  # Returns 1 if the numbers are equal, 0 otherwise.
  def op_numequal
    a, b = pop_int(2)
    @stack << (a == b ? 1 : 0)
  end

  # Returns 1 if the numbers are not equal, 0 otherwise.
  def op_numnotequal
    a, b = pop_int(2)
    @stack << (a != b ? 1 : 0)
  end

  # Marks transaction as invalid.
  def op_return
    @script_invalid = true; nil
  end

  # Copies the second-to-top stack item to the top.
  def op_over
    item = @stack[-2]
    @stack << item if item
  end

  # If the top stack value is not 0, the statements are executed. The top stack value is removed.
  def op_if
    value = false
    if @do_exec
      return if @stack.size < 1
      value = pop_int(1) == 1 ? true : false
    end
    @exec_stack << value
  end

  # If the top stack value is 0, the statements are executed. The top stack value is removed.
  def op_notif
    value = false
    if @do_exec
      return if @stack.size < 1
      value = pop_int(1) == 1 ? false : true
    end
    @exec_stack << value
  end

  # If the preceding OP_IF or OP_NOTIF or OP_ELSE was not executed then these statements are and if the preceding OP_IF or OP_NOTIF or OP_ELSE was executed then these statements are not.
  def op_else
    return if @exec_stack.empty?
    @exec_stack[-1] = !@exec_stack[-1]
  end

  # Ends an if/else block.
  def op_endif
    return if @exec_stack.empty?
    @exec_stack.pop
  end

  # The item n back in the stack is copied to the top.
  def op_pick
    pos = pop_int(1)
    item = @stack[-(pos+1)]
    @stack << item if item
  end

  # The item n back in the stack is moved to the top.
  def op_roll
    pos = pop_int(1)
    idx = -(pos+1)
    item = @stack[idx]
    if item
      @stack.delete_at(idx)
      @stack << item if item
    end
  end

  # The top three items on the stack are rotated to the left.
  def op_rot
    return if @stack.size < 3
    @stack[-3..-1] = [ @stack[-2], @stack[-1], @stack[-3] ]
  end

  # Removes the top two stack items.
  def op_2drop
    @stack.pop(2)
  end

  # Duplicates the top two stack items.
  def op_2dup
    @stack.push(*@stack[-2..-1])
  end

  # Duplicates the top three stack items.
  def op_3dup
    @stack.push(*@stack[-3..-1])
  end

  # Removes the second-to-top stack item.
  def op_nip
    @stack.delete_at(-2)
  end

  # Returns the length of the input string.
  def op_size
    item = @stack[-1]
    size = case item
           when String; item.bytesize
           when Fixnum; OpenSSL::BN.new(item.to_s(16), 16).to_mpi.size - 4
           end
    @stack << size
  end

  # Transaction is invalid unless occuring in an unexecuted OP_IF branch
  def op_ver
    # skipped, not defined in origin script.cpp
  end

  def pop_int(count=1)
    return cast_to_bignum(@stack.pop) if count == 1
    @stack.pop(count).map{|i| cast_to_bignum(i) }
  end

  def cast_to_bignum(buf)
    case buf
    when Fixnum; buf
    #when String; buf.unpack("H*")[0].to_i(16)
    when String; OpenSSL::BN.new([buf.bytesize].pack("N") + buf.reverse, 0).to_i
    #when String; OpenSSL::BN.new(buf.unpack("H*")[0], 16).to_i
    else; raise 'cast_to_bignum: failed to cast: %s (%s)' % [buf, buf.class]
    end
  end

  # Same as OP_NUMEQUAL, but runs OP_VERIFY afterward.
  def op_numequalverify
    op_numequal; op_verify
  end

  # https://en.bitcoin.it/wiki/BIP_0017  (old OP_NOP2)
  # TODO: don't rely on it yet. add guards from wikipage too.
  def op_checkhashverify
    # unless @checkhash && (@checkhash == @stack[-1].unpack("H*")[0])
    #  @script_invalid = true
    # end
  end

  # All of the signature checking words will only match signatures
  # to the data after the most recently-executed OP_CODESEPARATOR.
  def op_codeseparator
    @codehash_start = @chunks.size - @chunks.reverse.index(OP_CODESEPARATOR)
  end

  # do a CHECKSIG operation on the current stack,
  # asking +check_callback+ to do the actual signature verification.
  # This is used by Protocol::Tx#verify_input_signature
  def op_checksig(check_callback)
    return invalid if @stack.size < 2
    pubkey = @stack.pop
    drop_sigs      = [@stack[-1].unpack("H*")[0]]
    sig, hash_type = parse_sig(@stack.pop)

    if @chunks.include?(OP_CHECKHASHVERIFY)
      # Subset of script starting at the most recent codeseparator to OP_CHECKSIG
      script_code, @checkhash = codehash_script(OP_CHECKSIG)
    elsif inner_p2sh?
      script_code = to_string
    else
      script_code, drop_sigs = nil, nil
    end

    if check_callback == nil # for tests
      @stack << 1
    else # real signature check callback
      @stack <<
        ((check_callback.call(pubkey, sig, hash_type, drop_sigs, script_code) == true) ? 1 : 0)
    end
  end

  def op_checksigverify(check_callback)
    op_checksig(check_callback)
    op_verify
  end

  # do a CHECKMULTISIG operation on the current stack,
  # asking +check_callback+ to do the actual signature verification.
  #
  # CHECKMULTISIG does a m-of-n signatures verification on scripts of the form:
  #  0 <sig1> <sig2> | 2 <pub1> <pub2> 2 OP_CHECKMULTISIG
  #  0 <sig1> <sig2> | 2 <pub1> <pub2> <pub3> 3 OP_CHECKMULTISIG
  #  0 <sig1> <sig2> <sig3> | 3 <pub1> <pub2> <pub3> 3 OP_CHECKMULTISIG
  #
  # see https://en.bitcoin.it/wiki/BIP_0011 for details.
  # see https://github.com/bitcoin/bitcoin/blob/master/src/script.cpp#L931
  #
  # TODO: validate signature order
  # TODO: take global opcode count
  def op_checkmultisig(check_callback)
    n_pubkeys = @stack.pop
    return invalid  unless (0..20).include?(n_pubkeys)
    return invalid  unless @stack.last(n_pubkeys).all?{|e| e.is_a?(String) && e != '' }
    #return invalid  if ((@op_count ||= 0) += n_pubkeys) > 201
    pubkeys = @stack.pop(n_pubkeys)

    n_sigs = @stack.pop
    return invalid  unless (0..n_pubkeys).include?(n_sigs)
    return invalid  unless @stack.last(n_sigs).all?{|e| e.is_a?(String) && e != '' }
    sigs = (drop_sigs = @stack.pop(n_sigs)).map{|s| parse_sig(s) }
    drop_sigs.map!{|i| i.unpack("H*")[0] }

    @stack.pop if @stack[-1] == '' # remove OP_NOP from stack

    if @chunks.include?(OP_CHECKHASHVERIFY)
      # Subset of script starting at the most recent codeseparator to OP_CHECKMULTISIG
      script_code, @checkhash = codehash_script(OP_CHECKMULTISIG)
    elsif inner_p2sh?
      script_code = to_string
    else
      script_code, drop_sigs = nil, nil
    end

    valid_sigs = 0
    sigs.each{|sig, hash_type| pubkeys.each{|pubkey|
        valid_sigs += 1  if check_callback.call(pubkey, sig, hash_type, drop_sigs, script_code)
      }}

    @stack << ((valid_sigs >= n_sigs) ? 1 : (invalid; 0))
  end

  # op_eval: https://en.bitcoin.it/wiki/BIP_0012
  #   the BIP was never accepted and must be handled as old OP_NOP1
  def op_nop1
  end

  OPCODES_METHOD = Hash[*instance_methods.grep(/^op_/).map{|m|
      [ (OPCODES.find{|k,v| v == m.to_s.upcase }.first rescue nil), m ]
    }.flatten]
  OPCODES_METHOD[0]  = :op_0
  OPCODES_METHOD[81] = :op_1

  def self.is_canonical_pubkey?(pubkey)
    return false if pubkey.bytesize < 33 # "Non-canonical public key: too short"
    case pubkey[0]
    when "\x04"
      return false if pubkey.bytesize != 65 # "Non-canonical public key: invalid length for uncompressed key"
    when "\x02", "\x03"
      return false if pubkey.bytesize != 33 # "Non-canonical public key: invalid length for compressed key"
    else
      return false # "Non-canonical public key: compressed nor uncompressed"
    end
    true
  end

  private

  def parse_sig(sig)
    hash_type = sig[-1].unpack("C")[0]
    sig = sig[0...-1]
    return sig, hash_type
  end
end
