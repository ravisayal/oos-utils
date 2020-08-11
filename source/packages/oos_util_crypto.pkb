create or replace package body oos_util_crypto
as

  -- To test: https://www.freeformatter.com/hmac-generator.html#ad-output
  --
    bmax32 constant number := power( 2, 32 ) - 1;
    bmax64 constant number := power( 2, 64 ) - 1;
    type tp_crypto is table of number;
    type tp_aes_tab is table of number index by pls_integer;
  --
    SP1 tp_crypto;
    SP2 tp_crypto;
    SP3 tp_crypto;
    SP4 tp_crypto;
    SP5 tp_crypto;
    SP6 tp_crypto;
    SP7 tp_crypto;
    SP8 tp_crypto;
  --
    function bitor( x number, y number )
    return number
    is
    begin
      return x + y - bitand( x, y );
    end;
  --
    function bitxor( x number, y number )
    return number
    is
    begin
      return x + y - 2 * bitand( x, y );
    end;
  --
    function shl( x number, b pls_integer )
    return number
    is
    begin
      return x * power( 2, b );
    end;
  --
    function shr( x number, b pls_integer )
    return number
    is
    begin
      return trunc( x / power( 2, b ) );
    end;
  --
    function bitor32( x integer, y integer )
    return integer
    is
    begin
      return bitand( x + y - bitand( x, y  ), bmax32 );
    end;
  --
    function bitxor32( x integer, y  integer  )
    return integer
    is
    begin
      return bitand( x + y - 2 * bitand( x, y ), bmax32 );
    end;
  --
    function ror32( x number, b pls_integer )
    return number
    is
      t number;
    begin
      t := bitand( x, bmax32 );
      return bitand( bitor( shr( t, b ), shl( t, 32 - b ) ), bmax32 );
    end;
  --
    function rol32( x number, b pls_integer )
    return number
    is
      t number;
    begin
      t := bitand( x, bmax32 );
      return bitand( bitor( shl( t, b ), shr( t, 32 - b ) ), bmax32 );
    end;
  --
    function ror64( x number, b pls_integer )
    return number
    is
      t number;
    begin
      t := bitand( x, bmax64 );
      return bitand( bitor( shr( t, b ), shl( t, 64 - b ) ), bmax64 );
    end;
  --
    function rol64( x number, b pls_integer )
    return number
    is
      t number;
    begin
      t := bitand( x, bmax64 );
      return bitand( bitor( shl( t, b ), shr( t, 64 - b ) ), bmax64 );
    end;
  --
    function ripemd160( p_msg raw )
    return raw
    is
      t_md varchar2(128);
      fmt2 varchar2(10) := 'fm0XXXXXXX';
      t_len pls_integer;
      t_pad_len pls_integer;
      t_pad varchar2(144);
      t_msg_buf varchar2(32766);
      t_idx pls_integer;
      t_chunksize pls_integer := 16320; -- 255 * 64
      t_block varchar2(128);
  --
      st tp_crypto;
      sl tp_crypto;
      sr tp_crypto;
  --
      procedure ff( a in out number, b number, c in out number, d number, e number, xi pls_integer, r pls_integer )
      is
        x number := utl_raw.cast_to_binary_integer( substr( t_block, xi * 8 + 1, 8 ), utl_raw.little_endian );
      begin
        a := bitand( rol32( a + bitxor( bitxor( b, c ), d ) + x, r ) + e, bmax32 );
        c := rol32( c, 10 );
      end;
  --
      procedure ll( a in out number, b number, c in out number, d number, e number, xi pls_integer, r pls_integer, h number )
      is
        x number := utl_raw.cast_to_binary_integer( substr( t_block, xi * 8 + 1, 8 ), utl_raw.little_endian );
      begin
        a := bitand( rol32( a + bitxor( b, bitor( c, - d - 1 ) ) + x + h, r ) + e, bmax32 );
        c := rol32( c, 10 );
      end;
  --
      procedure gg( a in out number, b number, c in out number, d number, e number, xi pls_integer, r pls_integer, h number )
      is
        x number := utl_raw.cast_to_binary_integer( substr( t_block, xi * 8 + 1, 8 ), utl_raw.little_endian );
      begin
        a := bitand( rol32( a + bitor( bitand( b, c ), bitand( - b - 1, d ) ) + x + h, r ) + e, bmax32 );
        c := rol32( c, 10 );
      end;
  --
      procedure kk( a in out number, b number, c in out number, d number, e number, xi pls_integer, r pls_integer, h number )
      is
        x number := utl_raw.cast_to_binary_integer( substr( t_block, xi * 8 + 1, 8 ), utl_raw.little_endian );
      begin
        a := bitand( rol32( a + bitor( bitand( b, d ), bitand( c, - d - 1 ) ) + x + h, r ) + e, bmax32 );
        c := rol32( c, 10 );
      end;
  --
      procedure hh( a in out number, b number, c in out number, d number, e number, xi pls_integer, r pls_integer, h number )
      is
        x number := utl_raw.cast_to_binary_integer( substr( t_block, xi * 8 + 1, 8 ), utl_raw.little_endian );
      begin
        a := bitand( rol32( a + bitxor( bitor( b, - c - 1 ), d ) + x + h, r ) + e, bmax32 );
        c := rol32( c, 10 );
      end;
  --
      procedure fa( ar in out tp_crypto, s pls_integer, xis tp_crypto, r_cnt tp_crypto )
      is
      begin
        for i in 1 .. 16
        loop
          ff( ar(mod(15-i+s,5)+1),ar(mod(16-i+s,5)+1),ar(mod(17-i+s,5)+1),ar(mod(18-i+s,5)+1),ar(mod(19-i+s,5)+1),xis(i),r_cnt(i) );
        end loop;
      end;
      procedure ga( ar in out tp_crypto, s pls_integer, h number, xis tp_crypto, r_cnt tp_crypto )
      is
      begin
        for i in 1 .. 16
        loop
          gg( ar(mod(15-i+s,5)+1),ar(mod(16-i+s,5)+1),ar(mod(17-i+s,5)+1),ar(mod(18-i+s,5)+1),ar(mod(19-i+s,5)+1),xis(i),r_cnt(i), h );
        end loop;
      end;
      procedure ha( ar in out tp_crypto, s pls_integer, h number, xis tp_crypto, r_cnt tp_crypto )
      is
      begin
        for i in 1 .. 16
        loop
          hh( ar(mod(15-i+s,5)+1),ar(mod(16-i+s,5)+1),ar(mod(17-i+s,5)+1),ar(mod(18-i+s,5)+1),ar(mod(19-i+s,5)+1),xis(i),r_cnt(i), h );
        end loop;
      end;
      procedure ka( ar in out tp_crypto, s pls_integer, h number, xis tp_crypto, r_cnt tp_crypto )
      is
      begin
        for i in 1 .. 16
        loop
          kk( ar(mod(15-i+s,5)+1),ar(mod(16-i+s,5)+1),ar(mod(17-i+s,5)+1),ar(mod(18-i+s,5)+1),ar(mod(19-i+s,5)+1),xis(i),r_cnt(i), h );
        end loop;
      end;
      procedure la( ar in out tp_crypto, s pls_integer, h number, xis tp_crypto, r_cnt tp_crypto )
      is
      begin
        for i in 1 .. 16
        loop
          ll( ar(mod(15-i+s,5)+1),ar(mod(16-i+s,5)+1),ar(mod(17-i+s,5)+1),ar(mod(18-i+s,5)+1),ar(mod(19-i+s,5)+1),xis(i),r_cnt(i), h );
        end loop;
      end;
    begin
      t_len := nvl( utl_raw.length( p_msg ), 0 );
      t_pad_len := 64 - mod( t_len, 64 );
      if t_pad_len < 9
      then
        t_pad_len := 64 + t_pad_len;
      end if;
      t_pad := rpad( '8', t_pad_len * 2 - 16, '0' )
         || utl_raw.cast_from_binary_integer( t_len * 8, utl_raw.little_endian )
         || '00000000';
  --
      st := tp_crypto( 1732584193 -- 67452301
                     , 4023233417 -- efcdab89
                     , 2562383102 -- 98badcfe
                     ,  271733878 -- 10325476
                     , 3285377520 -- c3d2e1f0
                     );
  --
      sl := tp_crypto( 0, 0, 0, 0, 0 );
      sr := tp_crypto( 0, 0, 0, 0, 0 );
  --
      t_idx := 1;
      while t_idx <= t_len + t_pad_len
      loop
        if t_len - t_idx + 1 >= t_chunksize
        then
          t_msg_buf := utl_raw.substr( p_msg, t_idx, t_chunksize );
          t_idx := t_idx + t_chunksize;
        else
          if t_idx <= t_len
          then
            t_msg_buf := utl_raw.substr( p_msg, t_idx );
            t_idx := t_len + 1;
          else
            t_msg_buf := '';
          end if;
          if nvl( length( t_msg_buf ), 0 ) + t_pad_len * 2 <= 32766
          then
            t_msg_buf := t_msg_buf || t_pad;
            t_idx := t_idx + t_pad_len;
          end if;
        end if;
        for i in 1 .. length( t_msg_buf ) / 128
        loop
          t_block := substr( t_msg_buf, i * 128 - 127, 128 );
  --
          for i in 1 .. 5
          loop
           sl(i) := st(i);
           sr(i) := st(i);
          end loop;
  --
          fa( sl, 1
            , tp_crypto( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15 )
            , tp_crypto(11,14,15,12, 5, 8, 7, 9,11,13,14,15, 6, 7, 9, 8 )
            );
          ga( sl, 5, 1518500249 -- 5a827999
            , tp_crypto( 7, 4,13, 1,10, 6,15, 3,12, 0, 9, 5, 2,14,11, 8 )
            , tp_crypto( 7, 6, 8,13,11, 9, 7,15, 7,12,15, 9,11, 7,13,12 )
            );
          ha( sl, 4, 1859775393  -- 6ed9eba1
            , tp_crypto( 3,10,14, 4, 9,15, 8, 1, 2, 7, 0, 6,13,11, 5,12 )
            , tp_crypto(11,13, 6, 7,14, 9,13,15,14, 8,13, 6, 5,12, 7, 5 )
            );
          ka( sl, 3, 2400959708  -- 8f1bbcdc
            , tp_crypto( 1, 9,11,10, 0, 8,12, 4,13, 3, 7,15,14, 5, 6, 2 )
            , tp_crypto(11,12,14,15,14,15, 9, 8, 9,14, 5, 6, 8, 6, 5,12 )
            );
          la( sl, 2, 2840853838  -- a953fd4e
            , tp_crypto( 4, 0, 5, 9, 7,12, 2,10,14, 1, 3, 8,11, 6,15,13 )
            , tp_crypto( 9,15, 5,11, 6, 8,13,12, 5,12,13,14,11, 8, 5, 6 )
            );
  --
          la( sr, 1, 1352829926  -- 50a28be6
            , tp_crypto( 5,14, 7, 0, 9, 2,11, 4,13, 6,15, 8, 1,10, 3,12 )
            , tp_crypto( 8, 9, 9,11,13,15,15, 5, 7, 7, 8,11,14,14,12, 6 )
            );
          ka( sr, 5, 1548603684  -- 5c4dd124
            , tp_crypto( 6,11, 3, 7, 0,13, 5,10,14,15, 8,12, 4, 9, 1, 2 )
            , tp_crypto( 9,13,15, 7,12, 8, 9,11, 7, 7,12, 7, 6,15,13,11 )
            );
          ha( sr, 4, 1836072691  -- 6d703ef3
            , tp_crypto(15, 5, 1, 3, 7,14, 6, 9,11, 8,12, 2,10, 0, 4,13 )
            , tp_crypto( 9, 7,15,11, 8, 6, 6,14,12,13, 5,14,13,13, 7, 5 )
            );
          ga( sr, 3, 2053994217  -- 7a6d76e9
            , tp_crypto( 8, 6, 4, 1, 3,11,15, 0, 5,12, 2,13, 9, 7,10,14 )
            , tp_crypto(15, 5, 8,11,14,14, 6,14, 6, 9,12, 9,12, 5,15, 8 )
            );
          fa( sr, 2
            , tp_crypto(12,15,10, 4, 1, 5, 8, 7, 6, 2,13,14, 0, 3, 9,11 )
            , tp_crypto( 8, 5,12, 9,12, 5,14, 6, 8,13, 6, 5,15,13,11,11 )
            );
  --
          sl(2) := bitand( sl(2) + st(1) + sr(3), bmax32 );
          st(1) := bitand( st(2) + sl(3) + sr(4), bmax32 );
          st(2) := bitand( st(3) + sl(4) + sr(5), bmax32 );
          st(3) := bitand( st(4) + sl(5) + sr(1), bmax32 );
          st(4) := bitand( st(5) + sl(1) + sr(2), bmax32 );
          st(5) := sl(2);
  --
        end loop;
      end loop;
  --
      t_md := utl_raw.reverse( to_char( st(1), fmt2 ) )
           || utl_raw.reverse( to_char( st(2), fmt2 ) )
           || utl_raw.reverse( to_char( st(3), fmt2 ) )
           || utl_raw.reverse( to_char( st(4), fmt2 ) )
           || utl_raw.reverse( to_char( st(5), fmt2 ) );
  --
      return t_md;
    end;
  --
    function md4( p_msg raw )
    return raw
    is
      t_md varchar2(128);
      fmt1 varchar2(10) := 'XXXXXXXX';
      fmt2 varchar2(10) := 'fm0XXXXXXX';
      t_len pls_integer;
      t_pad_len pls_integer;
      t_pad varchar2(144);
      t_msg_buf varchar2(32766);
      t_idx pls_integer;
      t_chunksize pls_integer := 16320; -- 255 * 64
      t_block varchar2(128);
      a number;
      b number;
      c number;
      d number;
      AA number;
      BB number;
      CC number;
      DD number;
  --
      procedure ff( a in out number, b number, c number, d number, xi number, s pls_integer )
      is
        x number := utl_raw.cast_to_binary_integer( substr( t_block, xi * 8 + 1, 8 ), utl_raw.little_endian );
      begin
        a := a + bitor( bitand( b, c ), bitand( - b - 1, d ) ) + x;
        a := rol32( a, s );
      end;
  --
      procedure gg( a in out number, b number, c number, d number, xi number, s pls_integer )
      is
        x number := utl_raw.cast_to_binary_integer( substr( t_block, xi * 8 + 1, 8 ), utl_raw.little_endian );
      begin
        a := a + bitor( bitor( bitand( b, c ), bitand( b, d ) ), bitand( c, d ) ) + x + 1518500249; -- to_number( '5a827999', 'xxxxxxxx' );
        a := rol32( a, s );
      end;
  --
      procedure hh( a in out number, b number, c number, d number, xi number, s pls_integer )
      is
        x number := utl_raw.cast_to_binary_integer( substr( t_block, xi * 8 + 1, 8 ), utl_raw.little_endian );
      begin
        a := a + bitxor( bitxor( b, c ), d ) + x + 1859775393; -- to_number( '6ed9eba1', 'xxxxxxxx' );
        a := rol32( a, s );
      end;
  --
    begin
      t_len := nvl( utl_raw.length( p_msg ), 0 );
      t_pad_len := 64 - mod( t_len, 64 );
      if t_pad_len < 9
      then
        t_pad_len := 64 + t_pad_len;
      end if;
      t_pad := rpad( '8', t_pad_len * 2 - 16, '0' )
         || utl_raw.cast_from_binary_integer( t_len * 8, utl_raw.little_endian )
         || '00000000';
  --
      AA := to_number( '67452301', fmt1 );
      BB := to_number( 'efcdab89', fmt1 );
      CC := to_number( '98badcfe', fmt1 );
      DD := to_number( '10325476', fmt1 );
  --
      t_idx := 1;
      while t_idx <= t_len + t_pad_len
      loop
        if t_len - t_idx + 1 >= t_chunksize
        then
          t_msg_buf := utl_raw.substr( p_msg, t_idx, t_chunksize );
          t_idx := t_idx + t_chunksize;
        else
          if t_idx <= t_len
          then
            t_msg_buf := utl_raw.substr( p_msg, t_idx );
            t_idx := t_len + 1;
          else
            t_msg_buf := '';
          end if;
          if nvl( length( t_msg_buf ), 0 ) + t_pad_len * 2 <= 32766
          then
            t_msg_buf := t_msg_buf || t_pad;
            t_idx := t_idx + t_pad_len;
          end if;
        end if;
        for i in 1 .. length( t_msg_buf ) / 128
        loop
          t_block := substr( t_msg_buf, i * 128 - 127, 128 );
          a := AA;
          b := BB;
          c := CC;
          d := DD;
  --
          for j in 0 .. 3
          loop
            ff( a, b, c, d, j * 4 + 0, 3 );
            ff( d, a, b, c, j * 4 + 1, 7 );
            ff( c, d, a, b, j * 4 + 2, 11 );
            ff( b, c, d, a, j * 4 + 3, 19 );
          end loop;
  --
          for j in 0 .. 3
          loop
            gg( a, b, c, d, j + 0, 3 );
            gg( d, a, b, c, j + 4, 5 );
            gg( c, d, a, b, j + 8, 9 );
            gg( b, c, d, a, j + 12, 13 );
          end loop;
  --
          for j in 0 .. 3
          loop
            hh( a, b, c, d, bitand( j, 1 ) * 2 + bitand( j, 2 ) / 2 + 0, 3 );
            hh( d, a, b, c, bitand( j, 1 ) * 2 + bitand( j, 2 ) / 2 + 8, 9 );
            hh( c, d, a, b, bitand( j, 1 ) * 2 + bitand( j, 2 ) / 2 + 4, 11 );
            hh( b, c, d, a, bitand( j, 1 ) * 2 + bitand( j, 2 ) / 2 + 12, 15 );
          end loop;
  --
          AA := bitand( AA + a, bmax32 );
          BB := bitand( BB + b, bmax32 );
          CC := bitand( CC + c, bmax32 );
          DD := bitand( DD + d, bmax32 );
        end loop;
      end loop;
  --
      t_md := utl_raw.reverse( to_char( AA, fmt2 ) )
           || utl_raw.reverse( to_char( BB, fmt2 ) )
           || utl_raw.reverse( to_char( CC, fmt2 ) )
           || utl_raw.reverse( to_char( DD, fmt2 ) );
  --
      return t_md;
    end;
  --
    function md5( p_msg raw )
    return raw
    is
      t_md varchar2(128);
      fmt1 varchar2(10) := 'XXXXXXXX';
      fmt2 varchar2(10) := 'fm0XXXXXXX';
      t_len pls_integer;
      t_pad_len pls_integer;
      t_pad varchar2(144);
      t_msg_buf varchar2(32766);
      t_idx pls_integer;
      t_chunksize pls_integer := 16320; -- 255 * 64
      t_block varchar2(128);
      type tp_tab is table of number;
      Ht tp_tab;
      K tp_tab;
      s tp_tab;
      H_str varchar2(64);
      K_str varchar2(512);
      a number;
      b number;
      c number;
      d number;
      e number;
      f number;
      g number;
      h number;
    begin
      t_len := nvl( utl_raw.length( p_msg ), 0 );
      t_pad_len := 64 - mod( t_len, 64 );
      if t_pad_len < 9
      then
        t_pad_len := 64 + t_pad_len;
      end if;
      t_pad := rpad( '8', t_pad_len * 2 - 16, '0' )
         || utl_raw.cast_from_binary_integer( t_len * 8, utl_raw.little_endian )
         || '00000000';
  --
      s := tp_tab( 7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22
                 , 5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20
                 , 4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23
                 , 6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21
                 );
  --
      H_str := '67452301efcdab8998badcfe10325476';
      Ht := tp_tab();
      Ht.extend(4);
      for i in 1 .. 4
      loop
        Ht(i) := to_number( substr( H_str, i * 8 - 7, 8 ), fmt1 );
      end loop;
  --
      K_str := 'd76aa478e8c7b756242070dbc1bdceeef57c0faf4787c62aa8304613fd469501'
            || '698098d88b44f7afffff5bb1895cd7be6b901122fd987193a679438e49b40821'
            || 'f61e2562c040b340265e5a51e9b6c7aad62f105d02441453d8a1e681e7d3fbc8'
            || '21e1cde6c33707d6f4d50d87455a14eda9e3e905fcefa3f8676f02d98d2a4c8a'
            || 'fffa39428771f6816d9d6122fde5380ca4beea444bdecfa9f6bb4b60bebfbc70'
            || '289b7ec6eaa127fad4ef308504881d05d9d4d039e6db99e51fa27cf8c4ac5665'
            || 'f4292244432aff97ab9423a7fc93a039655b59c38f0ccc92ffeff47d85845dd1'
            || '6fa87e4ffe2ce6e0a30143144e0811a1f7537e82bd3af2352ad7d2bbeb86d391';
      K := tp_tab();
      K.extend(64);
      for i in 1 .. 64
      loop
        K(i) := to_number( substr( K_str, i * 8 - 7, 8 ), fmt1 );
      end loop;
      t_idx := 1;
      while t_idx <= t_len + t_pad_len
      loop
        if t_len - t_idx + 1 >= t_chunksize
        then
          t_msg_buf := utl_raw.substr( p_msg, t_idx, t_chunksize );
          t_idx := t_idx + t_chunksize;
        else
          if t_idx <= t_len
          then
            t_msg_buf := utl_raw.substr( p_msg, t_idx );
            t_idx := t_len + 1;
          else
            t_msg_buf := '';
          end if;
          if nvl( length( t_msg_buf ), 0 ) + t_pad_len * 2 <= 32766
          then
            t_msg_buf := t_msg_buf || t_pad;
            t_idx := t_idx + t_pad_len;
          end if;
        end if;
        for i in 1 .. length( t_msg_buf ) / 128
        loop
          t_block := substr( t_msg_buf, i * 128 - 127, 128 );
          a := Ht(1);
          b := Ht(2);
          c := Ht(3);
          d := Ht(4);
          for j in 0 .. 63
          loop
            if j <= 15
            then
              F := bitand( bitxor( D, bitand( B, bitxor( C, D ) ) ), bmax32 );
              g := j;
            elsif j <= 31
            then
              F := bitand( bitxor( C, bitand( D, bitxor( B, C ) ) ), bmax32 );
              g := mod( 5*j + 1, 16 );
            elsif j <= 47
            then
              F := bitand( bitxor( B, bitxor( C, D ) ), bmax32 );
              g := mod( 3*j + 5, 16 );
            else
              F := bitand( bitxor( C, bitor( B, - D  - 1 ) ), bmax32 );
              g := mod( 7*j, 16 );
            end if;
            e := D;
            D := C;
            C := B;
            h := utl_raw.cast_to_binary_integer( substr( t_block, g * 8 + 1, 8 ), utl_raw.little_endian );
            B := bitand( B + rol32( bitand( A + F + k( j + 1 ) + h, bmax32 ), s( j + 1 ) ), bmax32 );
            A := e;
          end loop;
          Ht(1) := bitand( Ht(1) + a, bmax32 );
          Ht(2) := bitand( Ht(2) + b, bmax32 );
          Ht(3) := bitand( Ht(3) + c, bmax32 );
          Ht(4) := bitand( Ht(4) + d, bmax32 );
        end loop;
      end loop;
  --
      for i in 1 .. 4
      loop
        t_md := t_md || utl_raw.reverse( to_char( Ht(i), fmt2 ) );
      end loop;
  --
      return t_md;
    end;
  --
    function sha1( p_val raw )
    return raw
    is
      t_val raw(32767);
      t_len pls_integer;
      t_padding raw(128);
      type tp_n is table of integer index by pls_integer;
      w tp_n;
      tw tp_n;
      th tp_n;
      c_ffffffff integer := to_number( 'ffffffff', 'xxxxxxxx' );
      c_5A827999 integer := to_number( '5A827999', 'xxxxxxxx' );
      c_6ED9EBA1 integer := to_number( '6ED9EBA1', 'xxxxxxxx' );
      c_8F1BBCDC integer := to_number( '8F1BBCDC', 'xxxxxxxx' );
      c_CA62C1D6 integer := to_number( 'CA62C1D6', 'xxxxxxxx' );
  --
      function radd( x integer, y integer )
      return integer
      is
      begin
        return x + y;
      end;
  --
    begin
      th(0) := to_number( hextoraw( '67452301' ), 'xxxxxxxx' );
      th(1) := to_number( hextoraw( 'EFCDAB89' ), 'xxxxxxxx' );
      th(2) := to_number( hextoraw( '98BADCFE' ), 'xxxxxxxx' );
      th(3) := to_number( hextoraw( '10325476' ), 'xxxxxxxx' );
      th(4) := to_number( hextoraw( 'C3D2E1F0' ), 'xxxxxxxx' );
  --
      t_len := nvl( utl_raw.length( p_val ), 0 );
      if mod( t_len, 64 ) < 55
      then
        t_padding :=  utl_raw.concat( hextoraw( '80' ), utl_raw.copies( hextoraw( '00' ), 55 - mod( t_len, 64 ) ) );
      elsif mod( t_len, 64 ) = 55
      then
        t_padding :=  hextoraw( '80' );
      else
        t_padding :=  utl_raw.concat( hextoraw( '80' ), utl_raw.copies( hextoraw( '00' ), 119 - mod( t_len, 64 ) ) );
      end if;
      t_padding := utl_raw.concat( t_padding
                                 , hextoraw( '00000000' )
                                 , utl_raw.cast_from_binary_integer( t_len * 8 ) -- only 32 bits number!!
                                 );
      t_val := utl_raw.concat( p_val, t_padding );
      for c in 0 .. utl_raw.length( t_val ) / 64 - 1
      loop
        for i in 0 .. 15
        loop
          w(i) := to_number( utl_raw.substr( t_val, c*64 + i*4 + 1, 4 ), 'xxxxxxxx' );
        end loop;
        for i in 16 .. 79
        loop
          w(i) := rol32( bitxor( bitxor( w(i-3), w(i-8) ), bitxor( w(i-14), w(i-16) ) ), 1 );
        end loop;
  --
        for i in 0 .. 4
        loop
          tw(i) := th(i);
        end loop;
  --
        for i in 0 .. 19
        loop
          tw(4-mod(i,5)) := tw(4-mod(i,5)) + rol32( tw(4-mod(i+4,5)), 5 )
                          + bitor( bitand( tw(4-mod(i+3,5)), tw(4-mod(i+2,5)) )
                                 , bitand( c_ffffffff - tw(4-mod(i+3,5)), tw(4-mod(i+1,5)) )
                                 )
                          + w(i) + c_5A827999;
          tw(4-mod(i+3,5)) := rol32( tw( 4-mod(i+3,5)), 30 );
        end loop;
        for i in 20 .. 39
        loop
          tw(4-mod(i,5)) := tw(4-mod(i,5)) + rol32( tw(4-mod(i+4,5)), 5 )
                          + bitxor( bitxor( tw(4-mod(i+3,5)), tw(4-mod(i+2,5)) )
                                  , tw(4-mod(i+1,5))
                                  )
                          + w(i) + c_6ED9EBA1;
          tw(4-mod(i+3,5)) := rol32( tw( 4-mod(i+3,5)), 30 );
        end loop;
        for i in 40 .. 59
        loop
          tw(4-mod(i,5)) := tw(4-mod(i,5)) + rol32( tw(4-mod(i+4,5)), 5 )
                          + bitor( bitand( tw(4-mod(i+3,5)), tw(4-mod(i+2,5)) )
                                 , bitor( bitand( tw(4-mod(i+3,5)), tw(4-mod(i+1,5)) )
                                                , bitand( tw(4-mod(i+2,5)), tw(4-mod(i+1,5)) )
                                                )
                                 )
                          + w(i) + c_8F1BBCDC;
          tw(4-mod(i+3,5)) := rol32( tw( 4-mod(i+3,5)), 30 );
        end loop;
        for i in 60 .. 79
        loop
          tw(4-mod(i,5)) := tw(4-mod(i,5)) + rol32( tw(4-mod(i+4,5)), 5 )
                          + bitxor( bitxor( tw(4-mod(i+3,5)), tw(4-mod(i+2,5)) )
                                  , tw(4-mod(i+1,5))
                                  )
                          + w(i) + c_CA62C1D6;
          tw(4-mod(i+3,5)) := rol32( tw( 4-mod(i+3,5)), 30 );
        end loop;
  --
        for i in 0 .. 4
        loop
          th(i) := bitand( th(i) + tw(i), bmax32 );
        end loop;
  --
      end loop;
  --
      return utl_raw.concat( to_char( th(0), 'fm0000000X' )
                           , to_char( th(1), 'fm0000000X' )
                           , to_char( th(2), 'fm0000000X' )
                           , to_char( th(3), 'fm0000000X' )
                           , to_char( th(4), 'fm0000000X' )
                           );
    end;
  --
    function sha256( p_msg raw, p_256 boolean )
    return raw
    is
      t_md varchar2(128);
      fmt1 varchar2(10) := 'xxxxxxxx';
      fmt2 varchar2(10) := 'fm0xxxxxxx';
      t_len pls_integer;
      t_pad_len pls_integer;
      t_pad varchar2(144);
      t_msg_buf varchar2(32766);
      t_idx pls_integer;
      t_chunksize pls_integer := 16320; -- 255 * 64
      t_block varchar2(128);
      type tp_tab is table of number;
      Ht tp_tab;
      K tp_tab;
      w tp_tab;
      H_str varchar2(64);
      K_str varchar2(512);
      a number;
      b number;
      c number;
      d number;
      e number;
      f number;
      g number;
      h number;
      s0 number;
      s1 number;
      maj number;
      ch number;
      t1 number;
      t2 number;
      tmp number;
    begin
      t_len := nvl( utl_raw.length( p_msg ), 0 );
      t_pad_len := 64 - mod( t_len, 64 );
      if t_pad_len < 9
      then
        t_pad_len := 64 + t_pad_len;
      end if;
      t_pad := rpad( '8', t_pad_len * 2 - 8, '0' ) || to_char( t_len * 8, 'fm0XXXXXXX' );
  --
      if p_256
      then
        H_str := '6a09e667bb67ae853c6ef372a54ff53a510e527f9b05688c1f83d9ab5be0cd19';
      else
        H_str := 'c1059ed8367cd5073070dd17f70e5939ffc00b316858151164f98fa7befa4fa4';
      end if;
      Ht := tp_tab();
      Ht.extend(8);
      for i in 1 .. 8
      loop
        Ht(i) := to_number( substr( H_str, i * 8 - 7, 8 ), fmt1 );
      end loop;
  --
      K_str := '428a2f9871374491b5c0fbcfe9b5dba53956c25b59f111f1923f82a4ab1c5ed5'
            || 'd807aa9812835b01243185be550c7dc372be5d7480deb1fe9bdc06a7c19bf174'
            || 'e49b69c1efbe47860fc19dc6240ca1cc2de92c6f4a7484aa5cb0a9dc76f988da'
            || '983e5152a831c66db00327c8bf597fc7c6e00bf3d5a7914706ca635114292967'
            || '27b70a852e1b21384d2c6dfc53380d13650a7354766a0abb81c2c92e92722c85'
            || 'a2bfe8a1a81a664bc24b8b70c76c51a3d192e819d6990624f40e3585106aa070'
            || '19a4c1161e376c082748774c34b0bcb5391c0cb34ed8aa4a5b9cca4f682e6ff3'
            || '748f82ee78a5636f84c878148cc7020890befffaa4506cebbef9a3f7c67178f2';
      K := tp_tab();
      K.extend(64);
      for i in 1 .. 64
      loop
        K(i) := to_number( substr( K_str, i * 8 - 7, 8 ), fmt1 );
      end loop;
  --
      t_idx := 1;
      while t_idx <= t_len + t_pad_len
      loop
        if t_len - t_idx + 1 >= t_chunksize
        then
          t_msg_buf := utl_raw.substr( p_msg, t_idx, t_chunksize );
          t_idx := t_idx + t_chunksize;
        else
          if t_idx <= t_len
          then
            t_msg_buf := utl_raw.substr( p_msg, t_idx );
            t_idx := t_len + 1;
          else
            t_msg_buf := '';
          end if;
          if nvl( length( t_msg_buf ), 0 ) + t_pad_len * 2 <= 32766
          then
            t_msg_buf := t_msg_buf || t_pad;
            t_idx := t_idx + t_pad_len;
          end if;
        end if;
  --
        for i in 1 .. length( t_msg_buf ) / 128
        loop
  --
          a := Ht(1);
          b := Ht(2);
          c := Ht(3);
          d := Ht(4);
          e := Ht(5);
          f := Ht(6);
          g := Ht(7);
          h := Ht(8);
  --
          t_block := substr( t_msg_buf, i * 128 - 127, 128 );
          w := tp_tab();
          w.extend( 64 );
          for j in 1 .. 16
          loop
            w(j) := to_number( substr( t_block, j * 8  - 7, 8 ), fmt1 );
          end loop;
  --
          for j in 17 .. 64
          loop
            tmp := w(j-15);
            s0 := bitxor( bitxor( ror32( tmp, 7), ror32( tmp, 18 ) ), shr( tmp, 3 ) );
            tmp := w(j-2);
            s1 := bitxor( bitxor( ror32( tmp, 17), ror32( tmp, 19 ) ), shr( tmp, 10 ) );
            w(j) := bitand( w(j-16) + s0 + w(j-7) + s1, bmax32 );
          end loop;
  --
          for j in 1 .. 64
          loop
            s0 := bitxor( bitxor( ror32( a, 2 ), ror32( a, 13 ) ), ror32( a, 22 ) );
            maj := bitxor( bitxor( bitand( a, b ), bitand( a, c ) ), bitand( b, c ) );
            t2 := bitand( s0 + maj, bmax32 );
            s1 := bitxor( bitxor( ror32( e, 6 ), ror32( e, 11 ) ), ror32( e, 25 ) );
            ch := bitxor( bitand( e, f ), bitand( - e - 1, g ) );
            t1 := h + s1 + ch + K(j) + w(j);
            h := g;
            g := f;
            f := e;
            e := d + t1;
            d := c;
            c := b;
            b := a;
            a := t1 + t2;
          end loop;
  --
          Ht(1) := bitand( Ht(1) + a, bmax32 );
          Ht(2) := bitand( Ht(2) + b, bmax32 );
          Ht(3) := bitand( Ht(3) + c, bmax32 );
          Ht(4) := bitand( Ht(4) + d, bmax32 );
          Ht(5) := bitand( Ht(5) + e, bmax32 );
          Ht(6) := bitand( Ht(6) + f, bmax32 );
          Ht(7) := bitand( Ht(7) + g, bmax32 );
          Ht(8) := bitand( Ht(8) + h, bmax32 );
  --
        end loop;
      end loop;
      for i in 1 .. case when p_256 then 8 else 7 end
      loop
        t_md := t_md || to_char( Ht(i), fmt2 );
      end loop;
      return t_md;
    end;
  --
    function sha512( p_msg raw, p_512 boolean )
    return raw
    is
      t_md varchar2(128);
      fmt1 varchar2(20) := 'xxxxxxxxxxxxxxxx';
      fmt2 varchar2(20) := 'fm0xxxxxxxxxxxxxxx';
      t_len pls_integer;
      t_pad_len pls_integer;
      t_pad varchar2(288);
      t_msg_buf varchar2(32766);
      t_idx pls_integer;
      t_chunksize pls_integer := 16256; -- 127 * 128
      t_block varchar2(256);
      type tp_tab is table of number;
      Ht tp_tab;
      K tp_tab;
      w tp_tab;
      H_str varchar2(128);
      K_str varchar2(1280);
      a number;
      b number;
      c number;
      d number;
      e number;
      f number;
      g number;
      h number;
      s0 number;
      s1 number;
      maj number;
      ch number;
      t1 number;
      t2 number;
      tmp number;
    begin
      t_len := nvl( utl_raw.length( p_msg ), 0 );
      t_pad_len := 128 - mod( t_len, 128 );
      if t_pad_len < 17
      then
        t_pad_len := 128 + t_pad_len;
      end if;
      t_pad := rpad( '8', t_pad_len * 2 - 16, '0' ) || to_char( t_len * 8, 'fm0XXXXXXX' );
  --
      if p_512
      then
        H_str := '6a09e667f3bcc908bb67ae8584caa73b3c6ef372fe94f82ba54ff53a5f1d36f1'
              || '510e527fade682d19b05688c2b3e6c1f1f83d9abfb41bd6b5be0cd19137e2179';
      else
        H_str := 'cbbb9d5dc1059ed8629a292a367cd5079159015a3070dd17152fecd8f70e5939'
              || '67332667ffc00b318eb44a8768581511db0c2e0d64f98fa747b5481dbefa4fa4';
      end if;
      Ht := tp_tab();
      Ht.extend(8);
      for i in 1 .. 8
      loop
        Ht(i) := to_number( substr( H_str, i * 16 - 15, 16 ), fmt1 );
      end loop;
  --
      K_str := '428a2f98d728ae227137449123ef65cdb5c0fbcfec4d3b2fe9b5dba58189dbbc'
            || '3956c25bf348b53859f111f1b605d019923f82a4af194f9bab1c5ed5da6d8118'
            || 'd807aa98a303024212835b0145706fbe243185be4ee4b28c550c7dc3d5ffb4e2'
            || '72be5d74f27b896f80deb1fe3b1696b19bdc06a725c71235c19bf174cf692694'
            || 'e49b69c19ef14ad2efbe4786384f25e30fc19dc68b8cd5b5240ca1cc77ac9c65'
            || '2de92c6f592b02754a7484aa6ea6e4835cb0a9dcbd41fbd476f988da831153b5'
            || '983e5152ee66dfaba831c66d2db43210b00327c898fb213fbf597fc7beef0ee4'
            || 'c6e00bf33da88fc2d5a79147930aa72506ca6351e003826f142929670a0e6e70'
            || '27b70a8546d22ffc2e1b21385c26c9264d2c6dfc5ac42aed53380d139d95b3df'
            || '650a73548baf63de766a0abb3c77b2a881c2c92e47edaee692722c851482353b'
            || 'a2bfe8a14cf10364a81a664bbc423001c24b8b70d0f89791c76c51a30654be30'
            || 'd192e819d6ef5218d69906245565a910f40e35855771202a106aa07032bbd1b8'
            || '19a4c116b8d2d0c81e376c085141ab532748774cdf8eeb9934b0bcb5e19b48a8'
            || '391c0cb3c5c95a634ed8aa4ae3418acb5b9cca4f7763e373682e6ff3d6b2b8a3'
            || '748f82ee5defb2fc78a5636f43172f6084c87814a1f0ab728cc702081a6439ec'
            || '90befffa23631e28a4506cebde82bde9bef9a3f7b2c67915c67178f2e372532b'
            || 'ca273eceea26619cd186b8c721c0c207eada7dd6cde0eb1ef57d4f7fee6ed178'
            || '06f067aa72176fba0a637dc5a2c898a6113f9804bef90dae1b710b35131c471b'
            || '28db77f523047d8432caab7b40c724933c9ebe0a15c9bebc431d67c49c100d4c'
            || '4cc5d4becb3e42b6597f299cfc657e2a5fcb6fab3ad6faec6c44198c4a475817';
      K := tp_tab();
      K.extend(80);
      for i in 1 .. 80
      loop
        K(i) := to_number( substr( K_str, i * 16 - 15, 16 ), fmt1 );
      end loop;
  --
      t_idx := 1;
      while t_idx <= t_len + t_pad_len
      loop
        if t_len - t_idx + 1 >= t_chunksize
        then
          t_msg_buf := utl_raw.substr( p_msg, t_idx, t_chunksize );
          t_idx := t_idx + t_chunksize;
        else
          if t_idx <= t_len
          then
            t_msg_buf := utl_raw.substr( p_msg, t_idx );
            t_idx := t_len + 1;
          else
            t_msg_buf := '';
          end if;
          if nvl( length( t_msg_buf ), 0 ) + t_pad_len * 2 <= 32766
          then
            t_msg_buf := t_msg_buf || t_pad;
            t_idx := t_idx + t_pad_len;
          end if;
        end if;
  --
        for i in 1 .. length( t_msg_buf ) / 256
        loop
  --
          a := Ht(1);
          b := Ht(2);
          c := Ht(3);
          d := Ht(4);
          e := Ht(5);
          f := Ht(6);
          g := Ht(7);
          h := Ht(8);
  --
          t_block := substr( t_msg_buf, i * 256 - 255, 256 );
          w := tp_tab();
          w.extend( 80 );
          for j in 1 .. 16
          loop
            w(j) := to_number( substr( t_block, j * 16  - 15, 16 ), fmt1 );
          end loop;
  --
          for j in 17 .. 80
          loop
            tmp := w(j-15);
            s0 := bitxor( bitxor( ror64( tmp, 1), ror64( tmp, 8 ) ), shr( tmp, 7 ) );
            tmp := w(j-2);
            s1 := bitxor( bitxor( ror64( tmp, 19), ror64( tmp, 61 ) ), shr( tmp, 6 ) );
            w(j) := bitand( w(j-16) + s0 + w(j-7) + s1, bmax64 );
          end loop;
  --
          for j in 1 .. 80
          loop
            s0 := bitxor( bitxor( ror64( a, 28 ), ror64( a, 34 ) ), ror64( a, 39 ) );
            maj := bitxor( bitxor( bitand( a, b ), bitand( a, c ) ), bitand( b, c ) );
            t2 := bitand( s0 + maj, bmax64 );
            s1 := bitxor( bitxor( ror64( e, 14 ), ror64( e, 18 ) ), ror64( e, 41 ) );
            ch := bitxor( bitand( e, f ), bitand( - e - 1, g ) );
            t1 := h + s1 + ch + K(j) + w(j);
            h := g;
            g := f;
            f := e;
            e := d + t1;
            d := c;
            c := b;
            b := a;
            a := t1 + t2;
          end loop;
  --
          Ht(1) := bitand( Ht(1) + a, bmax64 );
          Ht(2) := bitand( Ht(2) + b, bmax64 );
          Ht(3) := bitand( Ht(3) + c, bmax64 );
          Ht(4) := bitand( Ht(4) + d, bmax64 );
          Ht(5) := bitand( Ht(5) + e, bmax64 );
          Ht(6) := bitand( Ht(6) + f, bmax64 );
          Ht(7) := bitand( Ht(7) + g, bmax64 );
          Ht(8) := bitand( Ht(8) + h, bmax64 );
  --
        end loop;
      end loop;
      for i in 1 .. case when p_512 then 8 else 6 end
      loop
        t_md := t_md || to_char( Ht(i), fmt2 );
      end loop;
      return t_md;
    end;

    /**
     * Generates hash with raw values
     * See `oos_util_crypto.hash_str` to handle wrapping
     *
     * @example
     * select
     *   rawtohex(
     *     oos_util_crypto.hash(
     *       p_src => sys.utl_raw.cast_to_raw('hello'),
     *       p_typ => 4 -- oos_util_crypto.gc_hash_sh256
     *     )
     *   ) example
     * from dual
     * ;
     *
     * EXAMPLE
     * 2CF24DBA5FB0A30E26E83B2AC5B9E29E1B161E5C1FA7425E73043362938B9824
     *
     * @author Aton Scheffer
     * @created 4-Oct-2016
     * @param p_src
     * @param p_typ see `oos_util_crypto.gc_hash*` variables
     * @return
     */
    function hash(
      p_src raw,
      p_typ pls_integer)
    return raw
    is
    begin
      return case p_typ
               when gc_hash_md4 then md4( p_src )
               when gc_hash_md5 then md5( p_src )
               when gc_hash_sh1 then sha1( p_src )
               when gc_hash_sh224 then sha256( p_src, false )
               when gc_hash_sh256 then sha256( p_src, true )
               when gc_hash_sh384 then sha512( p_src, false )
               when gc_hash_sh512 then sha512( p_src, true )
               when gc_hash_ripemd160 then ripemd160( p_src )
             end;
    end;

    /**
     * Generates hash
     *
     *
     * @example
     * select
     *   oos_util_crypto.hash_str(
     *     p_src => 'hello',
     *     p_typ => 4 -- oos_util_crypto.gc_hash_md5
     *   ) example
     * from dual
     * ;
     *
     * EXAMPLE
     * 2CF24DBA5FB0A30E26E83B2AC5B9E29E1B161E5C1FA7425E73043362938B9824
     *
     * @author Martin D'Souza
     * @created 19-Jun-2017
     * @param p_src
     * @param p_typ see `oos_util_crypto.gc_hash*` variables
     * @return Hex hashed value as a string
     */
    function hash_str(
      p_src varchar2,
      p_typ pls_integer)
      return varchar2
    as
    begin
      return rawtohex(
        hash(
          p_src => sys.utl_raw.cast_to_raw(p_src),
          p_typ => p_typ)
        );
    end hash_str;

    /**
     * Generates mac
     * Note: see mac_str for string inputs
     *
     * @example
     * select
     *   rawtohex(
     *     oos_util_crypto.mac(
     *       p_src => utl_raw.cast_to_raw('hello'),
     *       p_typ => 3, -- oos_util_crypto.gc_hmac_sh256
     *       p_key => utl_raw.cast_to_raw('abc')
     *     )
     *   ) example
     * from dual
     * ;
     *
     * EXAMPLE
     * F3166A3A404599D2046ED2AAE479B37D54B51D2E85259C9E314042753BE7D813
     *
     * @author Aton Scheffer
     * @created 4-Oct-2016
     * @param p_src
     * @param p_typ see `oos_util_crypto.gc_hmac*` variables
     * @param p_key secret key
     * @return
     */
    function mac(
      p_src raw,
      p_typ pls_integer,
      p_key raw )
    return raw
    is
      t_key raw(128);
      t_len pls_integer;
      t_blocksize pls_integer := case
                                   when p_typ in ( gc_HMAC_SH384, gc_HMAC_SH512 )
                                     then 128
                                     else 64
                                 end;
      t_typ pls_integer := case p_typ
                             when gc_hmac_md4       then gc_hash_md4
                             when gc_hmac_md5       then gc_hash_md5
                             when gc_hmac_sh1       then gc_hash_sh1
                             when gc_hmac_sh224     then gc_hash_sh224
                             when gc_hmac_sh256     then gc_hash_sh256
                             when gc_hmac_sh384     then gc_hash_sh384
                             when gc_hmac_sh512     then gc_hash_sh512
                             when gc_hmac_ripemd160 then gc_hash_ripemd160
                           end;
    begin
      t_len := utl_raw.length( p_key );
      if t_len > t_blocksize
      then
        t_key := hash( p_key, t_typ );
        t_len := utl_raw.length( t_key );
      else
        t_key := p_key;
      end if;
      if t_len < t_blocksize
      then
        t_key := utl_raw.concat( t_key, utl_raw.copies( hextoraw( '00' ), t_blocksize - t_len ) );
      elsif t_len is null
      then
        t_key := utl_raw.copies( hextoraw( '00' ), t_blocksize );
      end if;
      return hash( utl_raw.concat( utl_raw.bit_xor( utl_raw.copies( hextoraw( '5c' ), t_blocksize ), t_key )
                                 , hash( utl_raw.concat( utl_raw.bit_xor( utl_raw.copies( hextoraw( '36' ), t_blocksize ), t_key )
                                                       , p_src
                                                       )
                                       , t_typ
                                       )
                                 )
                 , t_typ
                 );
    end;


    /**
     * Generates mac with string input / output
     *
     *
     * @example
     * select
     *   oos_util_crypto.mac_str(
     *     p_src => 'hello',
     *     p_typ => 3, -- oos_util_crypto.gc_hmac_sh256
     *     p_key => 'abc'
     *   ) example
     * from dual
     * ;
     *
     * EXAMPLE
     * F3166A3A404599D2046ED2AAE479B37D54B51D2E85259C9E314042753BE7D813
     *
     * @author Martin D'Souza
     * @created 19-Jun-2017
     * @param p_src
     * @param p_typ see `oos_util_crypto.gc_hmac*` variables
     * @param p_key secret key
     * @return mac hex value as varchar2
     */
    function mac_str(
      p_src varchar2,
      p_typ pls_integer,
      p_key varchar2 )
      return varchar2
    as
    begin
      return
        rawtohex(
          oos_util_crypto.mac(
            p_src => utl_raw.cast_to_raw(p_src),
            p_typ => p_typ,
            p_key => utl_raw.cast_to_raw(p_key)
         )
       );
    end mac_str;

  --
    function randombytes( number_bytes positive )
    return raw
    is
      type tp_arcfour_sbox is table of pls_integer index by pls_integer;
      type tp_arcfour is record
        ( s tp_arcfour_sbox
        , i pls_integer
        , j pls_integer
        );
      t_tmp pls_integer;
      t_s2 tp_arcfour_sbox;
      t_arcfour tp_arcfour;
      t_rv varchar2(32767);
      t_seed varchar2(3999);
    begin
      t_seed := utl_raw.cast_from_number( dbms_utility.get_cpu_time )
             || utl_raw.cast_from_number( extract( second from systimestamp ) )
             || utl_raw.cast_from_number( dbms_utility.get_time );
      for i in 0 .. 255
      loop
        t_arcfour.s(i) := i;
      end loop;
      t_seed := t_seed
             || utl_raw.cast_from_number( dbms_utility.get_time )
             || utl_raw.cast_from_number( extract( second from systimestamp ) )
             || utl_raw.cast_from_number( dbms_utility.get_cpu_time );
      for i in 0 .. 255
      loop
        t_s2(i) := to_number( substr( t_seed, mod( i, length( t_seed ) ) + 1, 1 ), 'XX' );
      end loop;
      t_arcfour.j := 0;
      for i in 0 .. 255
      loop
        t_arcfour.j := mod( t_arcfour.j + t_arcfour.s(i) + t_s2(i), 256 );
        t_tmp := t_arcfour.s(i);
        t_arcfour.s(i) := t_arcfour.s( t_arcfour.j );
        t_arcfour.s( t_arcfour.j ) := t_tmp;
      end loop;
      t_arcfour.i := 0;
      t_arcfour.j := 0;
  --
      for i in 1 .. 1536
      loop
        t_arcfour.i := bitand( t_arcfour.i + 1, 255 );
        t_arcfour.j := bitand( t_arcfour.j + t_arcfour.s( t_arcfour.i ), 255 );
        t_tmp := t_arcfour.s( t_arcfour.i );
        t_arcfour.s( t_arcfour.i ) := t_arcfour.s( t_arcfour.j );
        t_arcfour.s( t_arcfour.j ) := t_tmp;
      end loop;
  --
      for i in 1 .. number_bytes
      loop
        t_arcfour.i := bitand( t_arcfour.i + 1, 255 );
        t_arcfour.j := bitand( t_arcfour.j + t_arcfour.s( t_arcfour.i ), 255 );
        t_tmp := t_arcfour.s( t_arcfour.i );
        t_arcfour.s( t_arcfour.i ) := t_arcfour.s( t_arcfour.j );
        t_arcfour.s( t_arcfour.j ) := t_tmp;
        t_rv := t_rv || to_char( t_arcfour.s( bitand( t_arcfour.s( t_arcfour.i ) + t_arcfour.s( t_arcfour.j ), 255 ) ), 'fm0x' );
      end loop;
      return t_rv;
    end;
  --
    procedure aes_encrypt_key
      ( key varchar2
      , p_encrypt_key out nocopy tp_aes_tab
      )
    is
      rcon tp_aes_tab;
      t_r number;
      SS varchar2(512);
      s1 number;
      s2 number;
      s3 number;
      t number;
      Nk pls_integer;
      n pls_integer;
      r pls_integer;
    begin
      SS := '637c777bf26b6fc53001672bfed7ab76ca82c97dfa5947f0add4a2af9ca472c0'
         || 'b7fd9326363ff7cc34a5e5f171d8311504c723c31896059a071280e2eb27b275'
         || '09832c1a1b6e5aa0523bd6b329e32f8453d100ed20fcb15b6acbbe394a4c58cf'
         || 'd0efaafb434d338545f9027f503c9fa851a3408f929d38f5bcb6da2110fff3d2'
         || 'cd0c13ec5f974417c4a77e3d645d197360814fdc222a908846eeb814de5e0bdb'
         || 'e0323a0a4906245cc2d3ac629195e479e7c8376d8dd54ea96c56f4ea657aae08'
         || 'ba78252e1ca6b4c6e8dd741f4bbd8b8a703eb5664803f60e613557b986c11d9e'
         || 'e1f8981169d98e949b1e87e9ce5528df8ca1890dbfe6426841992d0fb054bb16';
      for i in 0 .. 255
      loop
        s1 := to_number( substr( SS, i * 2 + 1, 2 ), 'XX' );
        s2 := s1 * 2;
        if s2 >= 256
        then
          s2 := bitxor( s2, 283 );
        end if;
        s3 := bitxor( s1, s2 );
        p_encrypt_key(i) := s1;
        t := bitor( bitor( bitor( shl( s2, 24 ), shl( s1, 16 ) ), shl( s1, 8 ) ), s3 );
        p_encrypt_key( 256 + i ) := t;
        t := rol32( t, 24 );
        p_encrypt_key( 512 + i ) := t;
        t := rol32( t, 24 );
        p_encrypt_key( 768 + i ) := t;
        t := rol32( t, 24 );
        p_encrypt_key( 1024 + i ) := t;
      end loop;
  --
      t_r := 1;
      rcon(0) := shl( t_r, 24 );
      for i in 1 .. 9
      loop
        t_r := t_r * 2;
        if t_r >= 256
        then
          t_r := bitxor( t_r, 283 );
        end if;
        rcon(i) := shl( t_r, 24 );
      end loop;
      rcon(7) := - rcon(7);
      Nk := length( key ) / 8;
      for i in 0 .. Nk - 1
      loop
        p_encrypt_key( 1280 + i ) := to_number( substr( key, i * 8 + 1, 8 ), 'xxxxxxxx' );
      end loop;
      n := 0;
      r := 0;
      for i in Nk .. Nk * 4 + 27
      loop
        t := p_encrypt_key( 1280 + i - 1 );
        if n = 0
        then
          n := Nk;
          t := bitor( bitor( shl( p_encrypt_key( bitand( shr( t, 16 ), 255 ) ), 24 )
                           , shl( p_encrypt_key( bitand( shr( t, 8  ), 255 ) ), 16 )
                           )
                    , bitor( shl( p_encrypt_key( bitand( t           , 255 ) ), 8 )
                           ,      p_encrypt_key( bitand( shr( t, 24 ), 255 ) )
                           )
                    );
          t := bitxor( t, rcon( r ) );
          r := r + 1;
        elsif ( Nk = 8 and n = 4 )
        then
          t := bitor( bitor( shl( p_encrypt_key( bitand( shr( t, 24 ), 255 ) ), 24 )
                           , shl( p_encrypt_key( bitand( shr( t, 16 ), 255 ) ), 16 )
                           )
                    , bitor( shl( p_encrypt_key( bitand( shr( t, 8  ), 255 ) ), 8 )
                           ,      p_encrypt_key( bitand( t           , 255 ) )
                           )
                    );
        end if;
        n := n -1;
        p_encrypt_key( 1280 + i ) := bitand( bitxor( p_encrypt_key( 1280 + i - Nk ), t ), bmax32 );
      end loop;
    end;
  --
    procedure aes_decrypt_key
      ( key varchar2
      , p_decrypt_key out nocopy tp_aes_tab
      )
  is
      Se tp_aes_tab;
      rek tp_aes_tab;
      rcon tp_aes_tab;
      SS varchar2(512);
      s1 number;
      s2 number;
      s3 number;
      i2 number;
      i4 number;
      i8 number;
      i9 number;
      ib number;
      id number;
      ie number;
      t number;
      Nk pls_integer;
      Nw pls_integer;
      n pls_integer;
      r pls_integer;
    begin
      SS := '637c777bf26b6fc53001672bfed7ab76ca82c97dfa5947f0add4a2af9ca472c0'
         || 'b7fd9326363ff7cc34a5e5f171d8311504c723c31896059a071280e2eb27b275'
         || '09832c1a1b6e5aa0523bd6b329e32f8453d100ed20fcb15b6acbbe394a4c58cf'
         || 'd0efaafb434d338545f9027f503c9fa851a3408f929d38f5bcb6da2110fff3d2'
         || 'cd0c13ec5f974417c4a77e3d645d197360814fdc222a908846eeb814de5e0bdb'
         || 'e0323a0a4906245cc2d3ac629195e479e7c8376d8dd54ea96c56f4ea657aae08'
         || 'ba78252e1ca6b4c6e8dd741f4bbd8b8a703eb5664803f60e613557b986c11d9e'
         || 'e1f8981169d98e949b1e87e9ce5528df8ca1890dbfe6426841992d0fb054bb16';
      for i in 0 .. 255
      loop
        s1 := to_number( substr( SS, i * 2 + 1, 2 ), 'XX' );
        i2 := i * 2;
        if i2 >= 256
        then
          i2 := bitxor( i2, 283 );
        end if;
        i4 := i2 * 2;
        if i4 >= 256
        then
          i4 := bitxor( i4, 283 );
        end if;
        i8 := i4 * 2;
        if i8 >= 256
        then
          i8 := bitxor( i8, 283 );
        end if;
        i9 := bitxor( i8, i );
        ib := bitxor( i9, i2 );
        id := bitxor( i9, i4 );
        ie := bitxor( bitxor( i8, i4 ), i2 );
        Se(i) := s1;
        p_decrypt_key( s1 ) := i;
        t := bitor( bitor( bitor( shl( ie, 24 ), shl( i9, 16 ) ), shl( id, 8 ) ), ib );
        p_decrypt_key( 256 + s1 ) := t;
        t := rol32( t, 24 );
        p_decrypt_key( 512 + s1 ) := t;
        t := rol32( t, 24 );
        p_decrypt_key( 768 + s1 ) := t;
        t := rol32( t, 24 );
        p_decrypt_key( 1024 + s1 ) := t;
      end loop;
  --
      t := 1;
      rcon(0) := shl( t, 24 );
      for i in 1 .. 9
      loop
        t := t * 2;
        if t >= 256
        then
          t := bitxor( t, 283 );
        end if;
        rcon(i) := shl( t, 24 );
      end loop;
      rcon(7) := - rcon(7);
      Nk := length( key ) / 8;
      Nw := 4 * ( Nk + 7 );
      for i in 0 .. Nk - 1
      loop
        rek(i) := to_number( substr( key, i * 8 + 1, 8 ), 'xxxxxxxx' );
      end loop;
      n := 0;
      r := 0;
      for i in Nk .. Nw - 1
      loop
        t := rek(i - 1);
        if n = 0
        then
          n := Nk;
          t := bitor( bitor( shl( Se( bitand( shr( t, 16 ), 255 ) ), 24 )
                           , shl( Se( bitand( shr( t, 8  ), 255 ) ), 16 )
                           )
                    , bitor( shl( Se( bitand( t           , 255 ) ), 8 )
                           ,      Se( bitand( shr( t, 24 ), 255 ) )
                           )
                    );
          t := bitxor( t, rcon( r ) );
          r := r + 1;
        elsif ( Nk = 8 and n = 4 )
        then
          t := bitor( bitor( shl( Se( bitand( shr( t, 24 ), 255 ) ), 24 )
                           , shl( Se( bitand( shr( t, 16 ), 255 ) ), 16 )
                           )
                    , bitor( shl( Se( bitand( shr( t, 8  ), 255 ) ), 8 )
                           ,      Se( bitand( t           , 255 ) )
                           )
                    );
        end if;
        n := n -1;
        rek(i) := bitand( bitxor( rek( i - Nk ), t ), bmax32 );
      end loop;
      for i in 0 .. 3
      loop
        p_decrypt_key( 1280 + i ) := rek(Nw - 4 + i);
      end loop;
      for i in 1 .. Nk + 5
      loop
        for j in 0 .. 3
        loop
          t:= rek( Nw - i * 4 - 4 + j );
          t := bitxor( bitxor( p_decrypt_key( 256 + bitand( Se( bitand( shr( t, 24 ), 255 ) ), 255 ) )
                             , p_decrypt_key( 512 + bitand( Se( bitand( shr( t, 16 ), 255 ) ), 255 ) )
                             )
                     , bitxor( p_decrypt_key( 768 + bitand( Se( bitand( shr( t, 8 ), 255 ) ), 255 ) )
                             , p_decrypt_key( 1024 + bitand( Se( bitand( t, 255 ) ), 255 ) )
                             )
                     );
          p_decrypt_key( 1280 + i * 4 + j ) := t;
        end loop;
      end loop;
      for i in Nw - 4 .. Nw - 1
      loop
        p_decrypt_key( 1280 + i ) := rek(i - Nw + 4);
      end loop;
    end;
  --
    function aes_encrypt
      ( src varchar2
      , klen pls_integer
      , p_decrypt_key tp_aes_tab
      )
    return raw
    is
      t0 number;
      t1 number;
      t2 number;
      t3 number;
      a0 number;
      a1 number;
      a2 number;
      a3 number;
      k pls_integer := 0;
  --
      function grv( a number, b number, c number, d number, v number )
      return varchar2
      is
        t number;
        rv varchar2(256);
      begin
        t := bitxor( p_decrypt_key( bitand( shr( a, 24 ), 255 ) ), shr( v, 24 ) );
        rv := substr( to_char( t, '0xxxxxxx' ), -2 );
        t := bitxor( p_decrypt_key( bitand( shr( b, 16 ), 255 ) ), shr( v, 16 ) );
        rv := rv || substr( to_char( t, '0xxxxxxx' ), -2 );
        t := bitxor( p_decrypt_key( bitand( shr( c, 8 ), 255 ) ), shr( v, 8 ) );
        rv := rv || substr( to_char( t, '0xxxxxxx' ), -2 );
        t := bitxor( p_decrypt_key( bitand( d, 255 ) ), v );
        return rv || substr( to_char( t, '0xxxxxxx' ), -2 );
      end;
    begin
      t0 := bitxor( to_number( substr( src,  1, 8 ), 'xxxxxxxx' ), p_decrypt_key( 1280 ) );
      t1 := bitxor( to_number( substr( src,  9, 8 ), 'xxxxxxxx' ), p_decrypt_key( 1281 ) );
      t2 := bitxor( to_number( substr( src, 17, 8 ), 'xxxxxxxx' ), p_decrypt_key( 1282 ) );
      t3 := bitxor( to_number( substr( src, 25, 8 ), 'xxxxxxxx' ), p_decrypt_key( 1283 ) );
      for i in 1 .. klen / 4 + 5
      loop
        k := k + 4;
        a0 := bitxor( bitxor( bitxor( p_decrypt_key( 256 + bitand( shr( t0, 24 ), 255 ) )
                                    , p_decrypt_key( 512 + bitand( shr( t1, 16 ), 255 ) )
                                    )
                            , bitxor( p_decrypt_key( 768 + bitand( shr( t2, 8 ), 255 ) )
                                    , p_decrypt_key( 1024 + bitand(    t3     , 255 ) )
                                    )
                            )
                    , p_decrypt_key( 1280 + i * 4 )
                    );
        a1 := bitxor( bitxor( bitxor( p_decrypt_key( 256 + bitand( shr( t1, 24 ), 255 ) )
                                    , p_decrypt_key( 512 + bitand( shr( t2, 16 ), 255 ) )
                                    )
                            , bitxor( p_decrypt_key( 768 + bitand( shr( t3, 8 ), 255 ) )
                                    , p_decrypt_key( 1024 + bitand(     t0     , 255 ) )
                                    )
                            )
                    , p_decrypt_key( 1280 + i * 4 + 1 )
                    );
        a2 := bitxor( bitxor( bitxor( p_decrypt_key( 256 + bitand( shr( t2, 24 ), 255 ) )
                                    , p_decrypt_key( 512 + bitand( shr( t3, 16 ), 255 ) )
                                    )
                            , bitxor( p_decrypt_key( 768 + bitand( shr( t0, 8 ), 255 ) )
                                    , p_decrypt_key( 1024 + bitand(     t1     , 255 ) )
                                    )
                            )
                    , p_decrypt_key( 1280 + i * 4 + 2 )
                    );
        a3 := bitxor( bitxor( bitxor( p_decrypt_key( 256 + bitand( shr( t3, 24 ), 255 ) )
                                    , p_decrypt_key( 512 + bitand( shr( t0, 16 ), 255 ) )
                                    )
                            , bitxor( p_decrypt_key( 768 + bitand( shr( t1, 8 ), 255 ) )
                                    , p_decrypt_key( 1024 + bitand(     t2     , 255 ) )
                                    )
                            )
                    , p_decrypt_key( 1280 + i * 4 + 3 )
                    );
        t0 := a0; t1 := a1; t2 := a2; t3 := a3;
      end loop;
      k := k + 4;
      return grv( t0, t1, t2, t3, p_decrypt_key( 1280 + k ) )
          || grv( t1, t2, t3, t0, p_decrypt_key( 1280 + k + 1 ) )
          || grv( t2, t3, t0, t1, p_decrypt_key( 1280 + k + 2 ) )
          || grv( t3, t0, t1, t2, p_decrypt_key( 1280 + k + 3 ) );
    end;
  --
    function aes_decrypt
      ( src varchar2
      , klen pls_integer
      , p_decrypt_key tp_aes_tab
      )
    return raw
    is
      t0 number;
      t1 number;
      t2 number;
      t3 number;
      a0 number;
      a1 number;
      a2 number;
      a3 number;
      k pls_integer := 0;
  --
      function grv( a number, b number, c number, d number, v number )
      return varchar2
      is
        t number;
        rv varchar2(256);
      begin
        t := bitxor( p_decrypt_key( bitand( shr( a, 24 ), 255 ) ), shr( v, 24 ) );
        rv := substr( to_char( t, '0xxxxxxx' ), -2 );
        t := bitxor( p_decrypt_key( bitand( shr( b, 16 ), 255 ) ), shr( v, 16 ) );
        rv := rv || substr( to_char( t, '0xxxxxxx' ), -2 );
        t := bitxor( p_decrypt_key( bitand( shr( c, 8 ), 255 ) ), shr( v, 8 ) );
        rv := rv || substr( to_char( t, '0xxxxxxx' ), -2 );
        t := bitxor( p_decrypt_key( bitand( d, 255 ) ), v );
        return rv || substr( to_char( t, '0xxxxxxx' ), -2 );
      end;
    begin
      t0 := bitxor( to_number( substr( src,  1, 8 ), 'xxxxxxxx' ), p_decrypt_key( 1280 ) );
      t1 := bitxor( to_number( substr( src,  9, 8 ), 'xxxxxxxx' ), p_decrypt_key( 1281 ) );
      t2 := bitxor( to_number( substr( src, 17, 8 ), 'xxxxxxxx' ), p_decrypt_key( 1282 ) );
      t3 := bitxor( to_number( substr( src, 25, 8 ), 'xxxxxxxx' ), p_decrypt_key( 1283 ) );
      for i in 1 .. klen / 4 + 5
      loop
        k := k + 4;
        a0 := bitxor( bitxor( bitxor( p_decrypt_key( 256 + bitand( shr( t0, 24 ), 255 ) )
                                    , p_decrypt_key( 512 + bitand( shr( t3, 16 ), 255 ) )
                                    )
                            , bitxor( p_decrypt_key( 768 + bitand( shr( t2, 8 ), 255 ) )
                                    , p_decrypt_key( 1024 + bitand(     t1     , 255 ) )
                                    )
                            )
                    , p_decrypt_key( 1280 + i * 4 )
                    );
        a1 := bitxor( bitxor( bitxor( p_decrypt_key( 256 + bitand( shr( t1, 24 ), 255 ) )
                                    , p_decrypt_key( 512 + bitand( shr( t0, 16 ), 255 ) )
                                    )
                            , bitxor( p_decrypt_key( 768 + bitand( shr( t3, 8 ), 255 ) )
                                    , p_decrypt_key( 1024 + bitand(     t2     , 255 ) )
                                    )
                            )
                    , p_decrypt_key( 1280 + i * 4 + 1 )
                    );
        a2 := bitxor( bitxor( bitxor( p_decrypt_key( 256 + bitand( shr( t2, 24 ), 255 ) )
                                    , p_decrypt_key( 512 + bitand( shr( t1, 16 ), 255 ) )
                                    )
                            , bitxor( p_decrypt_key( 768 + bitand( shr( t0, 8 ), 255 ) )
                                    , p_decrypt_key( 1024 + bitand(     t3     , 255 ) )
                                    )
                            )
                    , p_decrypt_key( 1280 + i * 4 + 2 )
                    );
        a3 := bitxor( bitxor( bitxor( p_decrypt_key( 256 + bitand( shr( t3, 24 ), 255 ) )
                                    , p_decrypt_key( 512 + bitand( shr( t2, 16 ), 255 ) )
                                    )
                            , bitxor( p_decrypt_key( 768 + bitand( shr( t1, 8 ), 255 ) )
                                    , p_decrypt_key( 1024 + bitand(     t0     , 255 ) )
                                    )
                            )
                    , p_decrypt_key( 1280 + i * 4 + 3 )
                    );
        t0 := a0; t1 := a1; t2 := a2; t3 := a3;
      end loop;
      k := k + 4;
      return grv( t0, t3, t2, t1, p_decrypt_key( 1280 + k ) )
          || grv( t1, t0, t3, t2, p_decrypt_key( 1280 + k + 1 ) )
          || grv( t2, t1, t0, t3, p_decrypt_key( 1280 + k + 2 ) )
          || grv( t3, t2, t1, t0, p_decrypt_key( 1280 + k + 3 ) );
    end;
  --
    procedure deskey( p_key raw, p_keys out tp_crypto, p_encrypt boolean )
    is
      bytebit tp_crypto := tp_crypto( 128, 64, 32, 16, 8, 4, 2, 1 );
      bigbyte tp_crypto := tp_crypto( to_number( '800000', 'XXXXXX' ), to_number( '400000', 'XXXXXX' ), to_number( '200000', 'XXXXXX' ), to_number( '100000', 'XXXXXX' )
                                    , to_number( '080000', 'XXXXXX' ), to_number( '040000', 'XXXXXX' ), to_number( '020000', 'XXXXXX' ), to_number( '010000', 'XXXXXX' )
                                    , to_number( '008000', 'XXXXXX' ), to_number( '004000', 'XXXXXX' ), to_number( '002000', 'XXXXXX' ), to_number( '001000', 'XXXXXX' )
                                    , to_number( '000800', 'XXXXXX' ), to_number( '000400', 'XXXXXX' ), to_number( '000200', 'XXXXXX' ), to_number( '000100', 'XXXXXX' )
                                    , to_number( '000080', 'XXXXXX' ), to_number( '000040', 'XXXXXX' ), to_number( '000020', 'XXXXXX' ), to_number( '000010', 'XXXXXX' )
                                    , to_number( '000008', 'XXXXXX' ), to_number( '000004', 'XXXXXX' ), to_number( '000002', 'XXXXXX' ), to_number( '000001', 'XXXXXX' )
                                    );
      pcl tp_crypto := tp_crypto( 56, 48, 40, 32, 24, 16,  8
                                ,  0, 57, 49, 41, 33, 25, 17
                                ,  9,  1, 58, 50, 42, 34, 26
                                , 18, 10,  2, 59, 51, 43, 35
                                , 62, 54, 46, 38, 30, 22, 14
                                ,  6, 61, 53, 45, 37, 29, 21
                                , 13,  5, 60, 52, 44, 36, 28
                                , 20, 12,  4, 27, 19, 11, 3
                                );
      pc2 tp_crypto := tp_crypto( 13, 16, 10, 23,  0,  4
                                ,  2, 27, 14,  5, 20,  9
                                , 22, 18, 11, 3 , 25,  7
                                , 15,  6, 26, 19, 12,  1
                                , 40, 51, 30, 36, 46, 54
                                , 29, 39, 50, 44, 32, 47
                                , 43, 48, 38, 55, 33, 52
                                , 45, 41, 49, 35, 28, 31
                                );
      totrot tp_crypto := tp_crypto( 1, 2, 4, 6, 8, 10, 12, 14
                                   , 15, 17, 19, 21, 23, 25, 27, 28
                                   );
      t_key tp_crypto := tp_crypto();
      pclm tp_crypto := tp_crypto();
      pcr tp_crypto := tp_crypto();
      kn tp_crypto := tp_crypto();
      t_l pls_integer;
      t_m pls_integer;
      t_n pls_integer;
      raw0 number;
      raw1 number;
      t_tmp number;
      rawi pls_integer;
      knli pls_integer;
    begin
  --
      if SP1 is null
      then
          SP1 := tp_crypto(
          to_number( '01010400', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '00010000', 'xxxxxxxx' ), to_number( '01010404', 'xxxxxxxx' ),
          to_number( '01010004', 'xxxxxxxx' ), to_number( '00010404', 'xxxxxxxx' ), to_number( '00000004', 'xxxxxxxx' ), to_number( '00010000', 'xxxxxxxx' ),
          to_number( '00000400', 'xxxxxxxx' ), to_number( '01010400', 'xxxxxxxx' ), to_number( '01010404', 'xxxxxxxx' ), to_number( '00000400', 'xxxxxxxx' ),
          to_number( '01000404', 'xxxxxxxx' ), to_number( '01010004', 'xxxxxxxx' ), to_number( '01000000', 'xxxxxxxx' ), to_number( '00000004', 'xxxxxxxx' ),
          to_number( '00000404', 'xxxxxxxx' ), to_number( '01000400', 'xxxxxxxx' ), to_number( '01000400', 'xxxxxxxx' ), to_number( '00010400', 'xxxxxxxx' ),
          to_number( '00010400', 'xxxxxxxx' ), to_number( '01010000', 'xxxxxxxx' ), to_number( '01010000', 'xxxxxxxx' ), to_number( '01000404', 'xxxxxxxx' ),
          to_number( '00010004', 'xxxxxxxx' ), to_number( '01000004', 'xxxxxxxx' ), to_number( '01000004', 'xxxxxxxx' ), to_number( '00010004', 'xxxxxxxx' ),
          to_number( '00000000', 'xxxxxxxx' ), to_number( '00000404', 'xxxxxxxx' ), to_number( '00010404', 'xxxxxxxx' ), to_number( '01000000', 'xxxxxxxx' ),
          to_number( '00010000', 'xxxxxxxx' ), to_number( '01010404', 'xxxxxxxx' ), to_number( '00000004', 'xxxxxxxx' ), to_number( '01010000', 'xxxxxxxx' ),
          to_number( '01010400', 'xxxxxxxx' ), to_number( '01000000', 'xxxxxxxx' ), to_number( '01000000', 'xxxxxxxx' ), to_number( '00000400', 'xxxxxxxx' ),
          to_number( '01010004', 'xxxxxxxx' ), to_number( '00010000', 'xxxxxxxx' ), to_number( '00010400', 'xxxxxxxx' ), to_number( '01000004', 'xxxxxxxx' ),
          to_number( '00000400', 'xxxxxxxx' ), to_number( '00000004', 'xxxxxxxx' ), to_number( '01000404', 'xxxxxxxx' ), to_number( '00010404', 'xxxxxxxx' ),
          to_number( '01010404', 'xxxxxxxx' ), to_number( '00010004', 'xxxxxxxx' ), to_number( '01010000', 'xxxxxxxx' ), to_number( '01000404', 'xxxxxxxx' ),
          to_number( '01000004', 'xxxxxxxx' ), to_number( '00000404', 'xxxxxxxx' ), to_number( '00010404', 'xxxxxxxx' ), to_number( '01010400', 'xxxxxxxx' ),
          to_number( '00000404', 'xxxxxxxx' ), to_number( '01000400', 'xxxxxxxx' ), to_number( '01000400', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ),
          to_number( '00010004', 'xxxxxxxx' ), to_number( '00010400', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '01010004', 'xxxxxxxx' )
      );
          SP2 := tp_crypto(
          to_number( '80108020', 'xxxxxxxx' ), to_number( '80008000', 'xxxxxxxx' ), to_number( '00008000', 'xxxxxxxx' ), to_number( '00108020', 'xxxxxxxx' ),
          to_number( '00100000', 'xxxxxxxx' ), to_number( '00000020', 'xxxxxxxx' ), to_number( '80100020', 'xxxxxxxx' ), to_number( '80008020', 'xxxxxxxx' ),
          to_number( '80000020', 'xxxxxxxx' ), to_number( '80108020', 'xxxxxxxx' ), to_number( '80108000', 'xxxxxxxx' ), to_number( '80000000', 'xxxxxxxx' ),
          to_number( '80008000', 'xxxxxxxx' ), to_number( '00100000', 'xxxxxxxx' ), to_number( '00000020', 'xxxxxxxx' ), to_number( '80100020', 'xxxxxxxx' ),
          to_number( '00108000', 'xxxxxxxx' ), to_number( '00100020', 'xxxxxxxx' ), to_number( '80008020', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ),
          to_number( '80000000', 'xxxxxxxx' ), to_number( '00008000', 'xxxxxxxx' ), to_number( '00108020', 'xxxxxxxx' ), to_number( '80100000', 'xxxxxxxx' ),
          to_number( '00100020', 'xxxxxxxx' ), to_number( '80000020', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '00108000', 'xxxxxxxx' ),
          to_number( '00008020', 'xxxxxxxx' ), to_number( '80108000', 'xxxxxxxx' ), to_number( '80100000', 'xxxxxxxx' ), to_number( '00008020', 'xxxxxxxx' ),
          to_number( '00000000', 'xxxxxxxx' ), to_number( '00108020', 'xxxxxxxx' ), to_number( '80100020', 'xxxxxxxx' ), to_number( '00100000', 'xxxxxxxx' ),
          to_number( '80008020', 'xxxxxxxx' ), to_number( '80100000', 'xxxxxxxx' ), to_number( '80108000', 'xxxxxxxx' ), to_number( '00008000', 'xxxxxxxx' ),
          to_number( '80100000', 'xxxxxxxx' ), to_number( '80008000', 'xxxxxxxx' ), to_number( '00000020', 'xxxxxxxx' ), to_number( '80108020', 'xxxxxxxx' ),
          to_number( '00108020', 'xxxxxxxx' ), to_number( '00000020', 'xxxxxxxx' ), to_number( '00008000', 'xxxxxxxx' ), to_number( '80000000', 'xxxxxxxx' ),
          to_number( '00008020', 'xxxxxxxx' ), to_number( '80108000', 'xxxxxxxx' ), to_number( '00100000', 'xxxxxxxx' ), to_number( '80000020', 'xxxxxxxx' ),
          to_number( '00100020', 'xxxxxxxx' ), to_number( '80008020', 'xxxxxxxx' ), to_number( '80000020', 'xxxxxxxx' ), to_number( '00100020', 'xxxxxxxx' ),
          to_number( '00108000', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '80008000', 'xxxxxxxx' ), to_number( '00008020', 'xxxxxxxx' ),
          to_number( '80000000', 'xxxxxxxx' ), to_number( '80100020', 'xxxxxxxx' ), to_number( '80108020', 'xxxxxxxx' ), to_number( '00108000', 'xxxxxxxx' )
      );
          SP3 := tp_crypto(
          to_number( '00000208', 'xxxxxxxx' ), to_number( '08020200', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '08020008', 'xxxxxxxx' ),
          to_number( '08000200', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '00020208', 'xxxxxxxx' ), to_number( '08000200', 'xxxxxxxx' ),
          to_number( '00020008', 'xxxxxxxx' ), to_number( '08000008', 'xxxxxxxx' ), to_number( '08000008', 'xxxxxxxx' ), to_number( '00020000', 'xxxxxxxx' ),
          to_number( '08020208', 'xxxxxxxx' ), to_number( '00020008', 'xxxxxxxx' ), to_number( '08020000', 'xxxxxxxx' ), to_number( '00000208', 'xxxxxxxx' ),
          to_number( '08000000', 'xxxxxxxx' ), to_number( '00000008', 'xxxxxxxx' ), to_number( '08020200', 'xxxxxxxx' ), to_number( '00000200', 'xxxxxxxx' ),
          to_number( '00020200', 'xxxxxxxx' ), to_number( '08020000', 'xxxxxxxx' ), to_number( '08020008', 'xxxxxxxx' ), to_number( '00020208', 'xxxxxxxx' ),
          to_number( '08000208', 'xxxxxxxx' ), to_number( '00020200', 'xxxxxxxx' ), to_number( '00020000', 'xxxxxxxx' ), to_number( '08000208', 'xxxxxxxx' ),
          to_number( '00000008', 'xxxxxxxx' ), to_number( '08020208', 'xxxxxxxx' ), to_number( '00000200', 'xxxxxxxx' ), to_number( '08000000', 'xxxxxxxx' ),
          to_number( '08020200', 'xxxxxxxx' ), to_number( '08000000', 'xxxxxxxx' ), to_number( '00020008', 'xxxxxxxx' ), to_number( '00000208', 'xxxxxxxx' ),
          to_number( '00020000', 'xxxxxxxx' ), to_number( '08020200', 'xxxxxxxx' ), to_number( '08000200', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ),
          to_number( '00000200', 'xxxxxxxx' ), to_number( '00020008', 'xxxxxxxx' ), to_number( '08020208', 'xxxxxxxx' ), to_number( '08000200', 'xxxxxxxx' ),
          to_number( '08000008', 'xxxxxxxx' ), to_number( '00000200', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '08020008', 'xxxxxxxx' ),
          to_number( '08000208', 'xxxxxxxx' ), to_number( '00020000', 'xxxxxxxx' ), to_number( '08000000', 'xxxxxxxx' ), to_number( '08020208', 'xxxxxxxx' ),
          to_number( '00000008', 'xxxxxxxx' ), to_number( '00020208', 'xxxxxxxx' ), to_number( '00020200', 'xxxxxxxx' ), to_number( '08000008', 'xxxxxxxx' ),
          to_number( '08020000', 'xxxxxxxx' ), to_number( '08000208', 'xxxxxxxx' ), to_number( '00000208', 'xxxxxxxx' ), to_number( '08020000', 'xxxxxxxx' ),
          to_number( '00020208', 'xxxxxxxx' ), to_number( '00000008', 'xxxxxxxx' ), to_number( '08020008', 'xxxxxxxx' ), to_number( '00020200', 'xxxxxxxx' )
      );
          SP4 := tp_crypto(
          to_number( '00802001', 'xxxxxxxx' ), to_number( '00002081', 'xxxxxxxx' ), to_number( '00002081', 'xxxxxxxx' ), to_number( '00000080', 'xxxxxxxx' ),
          to_number( '00802080', 'xxxxxxxx' ), to_number( '00800081', 'xxxxxxxx' ), to_number( '00800001', 'xxxxxxxx' ), to_number( '00002001', 'xxxxxxxx' ),
          to_number( '00000000', 'xxxxxxxx' ), to_number( '00802000', 'xxxxxxxx' ), to_number( '00802000', 'xxxxxxxx' ), to_number( '00802081', 'xxxxxxxx' ),
          to_number( '00000081', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '00800080', 'xxxxxxxx' ), to_number( '00800001', 'xxxxxxxx' ),
          to_number( '00000001', 'xxxxxxxx' ), to_number( '00002000', 'xxxxxxxx' ), to_number( '00800000', 'xxxxxxxx' ), to_number( '00802001', 'xxxxxxxx' ),
          to_number( '00000080', 'xxxxxxxx' ), to_number( '00800000', 'xxxxxxxx' ), to_number( '00002001', 'xxxxxxxx' ), to_number( '00002080', 'xxxxxxxx' ),
          to_number( '00800081', 'xxxxxxxx' ), to_number( '00000001', 'xxxxxxxx' ), to_number( '00002080', 'xxxxxxxx' ), to_number( '00800080', 'xxxxxxxx' ),
          to_number( '00002000', 'xxxxxxxx' ), to_number( '00802080', 'xxxxxxxx' ), to_number( '00802081', 'xxxxxxxx' ), to_number( '00000081', 'xxxxxxxx' ),
          to_number( '00800080', 'xxxxxxxx' ), to_number( '00800001', 'xxxxxxxx' ), to_number( '00802000', 'xxxxxxxx' ), to_number( '00802081', 'xxxxxxxx' ),
          to_number( '00000081', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '00802000', 'xxxxxxxx' ),
          to_number( '00002080', 'xxxxxxxx' ), to_number( '00800080', 'xxxxxxxx' ), to_number( '00800081', 'xxxxxxxx' ), to_number( '00000001', 'xxxxxxxx' ),
          to_number( '00802001', 'xxxxxxxx' ), to_number( '00002081', 'xxxxxxxx' ), to_number( '00002081', 'xxxxxxxx' ), to_number( '00000080', 'xxxxxxxx' ),
          to_number( '00802081', 'xxxxxxxx' ), to_number( '00000081', 'xxxxxxxx' ), to_number( '00000001', 'xxxxxxxx' ), to_number( '00002000', 'xxxxxxxx' ),
          to_number( '00800001', 'xxxxxxxx' ), to_number( '00002001', 'xxxxxxxx' ), to_number( '00802080', 'xxxxxxxx' ), to_number( '00800081', 'xxxxxxxx' ),
          to_number( '00002001', 'xxxxxxxx' ), to_number( '00002080', 'xxxxxxxx' ), to_number( '00800000', 'xxxxxxxx' ), to_number( '00802001', 'xxxxxxxx' ),
          to_number( '00000080', 'xxxxxxxx' ), to_number( '00800000', 'xxxxxxxx' ), to_number( '00002000', 'xxxxxxxx' ), to_number( '00802080', 'xxxxxxxx' )
      );
          SP5 := tp_crypto(
          to_number( '00000100', 'xxxxxxxx' ), to_number( '02080100', 'xxxxxxxx' ), to_number( '02080000', 'xxxxxxxx' ), to_number( '42000100', 'xxxxxxxx' ),
          to_number( '00080000', 'xxxxxxxx' ), to_number( '00000100', 'xxxxxxxx' ), to_number( '40000000', 'xxxxxxxx' ), to_number( '02080000', 'xxxxxxxx' ),
          to_number( '40080100', 'xxxxxxxx' ), to_number( '00080000', 'xxxxxxxx' ), to_number( '02000100', 'xxxxxxxx' ), to_number( '40080100', 'xxxxxxxx' ),
          to_number( '42000100', 'xxxxxxxx' ), to_number( '42080000', 'xxxxxxxx' ), to_number( '00080100', 'xxxxxxxx' ), to_number( '40000000', 'xxxxxxxx' ),
          to_number( '02000000', 'xxxxxxxx' ), to_number( '40080000', 'xxxxxxxx' ), to_number( '40080000', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ),
          to_number( '40000100', 'xxxxxxxx' ), to_number( '42080100', 'xxxxxxxx' ), to_number( '42080100', 'xxxxxxxx' ), to_number( '02000100', 'xxxxxxxx' ),
          to_number( '42080000', 'xxxxxxxx' ), to_number( '40000100', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '42000000', 'xxxxxxxx' ),
          to_number( '02080100', 'xxxxxxxx' ), to_number( '02000000', 'xxxxxxxx' ), to_number( '42000000', 'xxxxxxxx' ), to_number( '00080100', 'xxxxxxxx' ),
          to_number( '00080000', 'xxxxxxxx' ), to_number( '42000100', 'xxxxxxxx' ), to_number( '00000100', 'xxxxxxxx' ), to_number( '02000000', 'xxxxxxxx' ),
          to_number( '40000000', 'xxxxxxxx' ), to_number( '02080000', 'xxxxxxxx' ), to_number( '42000100', 'xxxxxxxx' ), to_number( '40080100', 'xxxxxxxx' ),
          to_number( '02000100', 'xxxxxxxx' ), to_number( '40000000', 'xxxxxxxx' ), to_number( '42080000', 'xxxxxxxx' ), to_number( '02080100', 'xxxxxxxx' ),
          to_number( '40080100', 'xxxxxxxx' ), to_number( '00000100', 'xxxxxxxx' ), to_number( '02000000', 'xxxxxxxx' ), to_number( '42080000', 'xxxxxxxx' ),
          to_number( '42080100', 'xxxxxxxx' ), to_number( '00080100', 'xxxxxxxx' ), to_number( '42000000', 'xxxxxxxx' ), to_number( '42080100', 'xxxxxxxx' ),
          to_number( '02080000', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '40080000', 'xxxxxxxx' ), to_number( '42000000', 'xxxxxxxx' ),
          to_number( '00080100', 'xxxxxxxx' ), to_number( '02000100', 'xxxxxxxx' ), to_number( '40000100', 'xxxxxxxx' ), to_number( '00080000', 'xxxxxxxx' ),
          to_number( '00000000', 'xxxxxxxx' ), to_number( '40080000', 'xxxxxxxx' ), to_number( '02080100', 'xxxxxxxx' ), to_number( '40000100', 'xxxxxxxx' )
      );
          SP6 := tp_crypto(
          to_number( '20000010', 'xxxxxxxx' ), to_number( '20400000', 'xxxxxxxx' ), to_number( '00004000', 'xxxxxxxx' ), to_number( '20404010', 'xxxxxxxx' ),
          to_number( '20400000', 'xxxxxxxx' ), to_number( '00000010', 'xxxxxxxx' ), to_number( '20404010', 'xxxxxxxx' ), to_number( '00400000', 'xxxxxxxx' ),
          to_number( '20004000', 'xxxxxxxx' ), to_number( '00404010', 'xxxxxxxx' ), to_number( '00400000', 'xxxxxxxx' ), to_number( '20000010', 'xxxxxxxx' ),
          to_number( '00400010', 'xxxxxxxx' ), to_number( '20004000', 'xxxxxxxx' ), to_number( '20000000', 'xxxxxxxx' ), to_number( '00004010', 'xxxxxxxx' ),
          to_number( '00000000', 'xxxxxxxx' ), to_number( '00400010', 'xxxxxxxx' ), to_number( '20004010', 'xxxxxxxx' ), to_number( '00004000', 'xxxxxxxx' ),
          to_number( '00404000', 'xxxxxxxx' ), to_number( '20004010', 'xxxxxxxx' ), to_number( '00000010', 'xxxxxxxx' ), to_number( '20400010', 'xxxxxxxx' ),
          to_number( '20400010', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '00404010', 'xxxxxxxx' ), to_number( '20404000', 'xxxxxxxx' ),
          to_number( '00004010', 'xxxxxxxx' ), to_number( '00404000', 'xxxxxxxx' ), to_number( '20404000', 'xxxxxxxx' ), to_number( '20000000', 'xxxxxxxx' ),
          to_number( '20004000', 'xxxxxxxx' ), to_number( '00000010', 'xxxxxxxx' ), to_number( '20400010', 'xxxxxxxx' ), to_number( '00404000', 'xxxxxxxx' ),
          to_number( '20404010', 'xxxxxxxx' ), to_number( '00400000', 'xxxxxxxx' ), to_number( '00004010', 'xxxxxxxx' ), to_number( '20000010', 'xxxxxxxx' ),
          to_number( '00400000', 'xxxxxxxx' ), to_number( '20004000', 'xxxxxxxx' ), to_number( '20000000', 'xxxxxxxx' ), to_number( '00004010', 'xxxxxxxx' ),
          to_number( '20000010', 'xxxxxxxx' ), to_number( '20404010', 'xxxxxxxx' ), to_number( '00404000', 'xxxxxxxx' ), to_number( '20400000', 'xxxxxxxx' ),
          to_number( '00404010', 'xxxxxxxx' ), to_number( '20404000', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '20400010', 'xxxxxxxx' ),
          to_number( '00000010', 'xxxxxxxx' ), to_number( '00004000', 'xxxxxxxx' ), to_number( '20400000', 'xxxxxxxx' ), to_number( '00404010', 'xxxxxxxx' ),
          to_number( '00004000', 'xxxxxxxx' ), to_number( '00400010', 'xxxxxxxx' ), to_number( '20004010', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ),
          to_number( '20404000', 'xxxxxxxx' ), to_number( '20000000', 'xxxxxxxx' ), to_number( '00400010', 'xxxxxxxx' ), to_number( '20004010', 'xxxxxxxx' )
      );
          SP7 := tp_crypto(
          to_number( '00200000', 'xxxxxxxx' ), to_number( '04200002', 'xxxxxxxx' ), to_number( '04000802', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ),
          to_number( '00000800', 'xxxxxxxx' ), to_number( '04000802', 'xxxxxxxx' ), to_number( '00200802', 'xxxxxxxx' ), to_number( '04200800', 'xxxxxxxx' ),
          to_number( '04200802', 'xxxxxxxx' ), to_number( '00200000', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '04000002', 'xxxxxxxx' ),
          to_number( '00000002', 'xxxxxxxx' ), to_number( '04000000', 'xxxxxxxx' ), to_number( '04200002', 'xxxxxxxx' ), to_number( '00000802', 'xxxxxxxx' ),
          to_number( '04000800', 'xxxxxxxx' ), to_number( '00200802', 'xxxxxxxx' ), to_number( '00200002', 'xxxxxxxx' ), to_number( '04000800', 'xxxxxxxx' ),
          to_number( '04000002', 'xxxxxxxx' ), to_number( '04200000', 'xxxxxxxx' ), to_number( '04200800', 'xxxxxxxx' ), to_number( '00200002', 'xxxxxxxx' ),
          to_number( '04200000', 'xxxxxxxx' ), to_number( '00000800', 'xxxxxxxx' ), to_number( '00000802', 'xxxxxxxx' ), to_number( '04200802', 'xxxxxxxx' ),
          to_number( '00200800', 'xxxxxxxx' ), to_number( '00000002', 'xxxxxxxx' ), to_number( '04000000', 'xxxxxxxx' ), to_number( '00200800', 'xxxxxxxx' ),
          to_number( '04000000', 'xxxxxxxx' ), to_number( '00200800', 'xxxxxxxx' ), to_number( '00200000', 'xxxxxxxx' ), to_number( '04000802', 'xxxxxxxx' ),
          to_number( '04000802', 'xxxxxxxx' ), to_number( '04200002', 'xxxxxxxx' ), to_number( '04200002', 'xxxxxxxx' ), to_number( '00000002', 'xxxxxxxx' ),
          to_number( '00200002', 'xxxxxxxx' ), to_number( '04000000', 'xxxxxxxx' ), to_number( '04000800', 'xxxxxxxx' ), to_number( '00200000', 'xxxxxxxx' ),
          to_number( '04200800', 'xxxxxxxx' ), to_number( '00000802', 'xxxxxxxx' ), to_number( '00200802', 'xxxxxxxx' ), to_number( '04200800', 'xxxxxxxx' ),
          to_number( '00000802', 'xxxxxxxx' ), to_number( '04000002', 'xxxxxxxx' ), to_number( '04200802', 'xxxxxxxx' ), to_number( '04200000', 'xxxxxxxx' ),
          to_number( '00200800', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '00000002', 'xxxxxxxx' ), to_number( '04200802', 'xxxxxxxx' ),
          to_number( '00000000', 'xxxxxxxx' ), to_number( '00200802', 'xxxxxxxx' ), to_number( '04200000', 'xxxxxxxx' ), to_number( '00000800', 'xxxxxxxx' ),
          to_number( '04000002', 'xxxxxxxx' ), to_number( '04000800', 'xxxxxxxx' ), to_number( '00000800', 'xxxxxxxx' ), to_number( '00200002', 'xxxxxxxx' )
      );
          SP8 := tp_crypto(
          to_number( '10001040', 'xxxxxxxx' ), to_number( '00001000', 'xxxxxxxx' ), to_number( '00040000', 'xxxxxxxx' ), to_number( '10041040', 'xxxxxxxx' ),
          to_number( '10000000', 'xxxxxxxx' ), to_number( '10001040', 'xxxxxxxx' ), to_number( '00000040', 'xxxxxxxx' ), to_number( '10000000', 'xxxxxxxx' ),
          to_number( '00040040', 'xxxxxxxx' ), to_number( '10040000', 'xxxxxxxx' ), to_number( '10041040', 'xxxxxxxx' ), to_number( '00041000', 'xxxxxxxx' ),
          to_number( '10041000', 'xxxxxxxx' ), to_number( '00041040', 'xxxxxxxx' ), to_number( '00001000', 'xxxxxxxx' ), to_number( '00000040', 'xxxxxxxx' ),
          to_number( '10040000', 'xxxxxxxx' ), to_number( '10000040', 'xxxxxxxx' ), to_number( '10001000', 'xxxxxxxx' ), to_number( '00001040', 'xxxxxxxx' ),
          to_number( '00041000', 'xxxxxxxx' ), to_number( '00040040', 'xxxxxxxx' ), to_number( '10040040', 'xxxxxxxx' ), to_number( '10041000', 'xxxxxxxx' ),
          to_number( '00001040', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ), to_number( '10040040', 'xxxxxxxx' ),
          to_number( '10000040', 'xxxxxxxx' ), to_number( '10001000', 'xxxxxxxx' ), to_number( '00041040', 'xxxxxxxx' ), to_number( '00040000', 'xxxxxxxx' ),
          to_number( '00041040', 'xxxxxxxx' ), to_number( '00040000', 'xxxxxxxx' ), to_number( '10041000', 'xxxxxxxx' ), to_number( '00001000', 'xxxxxxxx' ),
          to_number( '00000040', 'xxxxxxxx' ), to_number( '10040040', 'xxxxxxxx' ), to_number( '00001000', 'xxxxxxxx' ), to_number( '00041040', 'xxxxxxxx' ),
          to_number( '10001000', 'xxxxxxxx' ), to_number( '00000040', 'xxxxxxxx' ), to_number( '10000040', 'xxxxxxxx' ), to_number( '10040000', 'xxxxxxxx' ),
          to_number( '10040040', 'xxxxxxxx' ), to_number( '10000000', 'xxxxxxxx' ), to_number( '00040000', 'xxxxxxxx' ), to_number( '10001040', 'xxxxxxxx' ),
          to_number( '00000000', 'xxxxxxxx' ), to_number( '10041040', 'xxxxxxxx' ), to_number( '00040040', 'xxxxxxxx' ), to_number( '10000040', 'xxxxxxxx' ),
          to_number( '10040000', 'xxxxxxxx' ), to_number( '10001000', 'xxxxxxxx' ), to_number( '10001040', 'xxxxxxxx' ), to_number( '00000000', 'xxxxxxxx' ),
          to_number( '10041040', 'xxxxxxxx' ), to_number( '00041000', 'xxxxxxxx' ), to_number( '00041000', 'xxxxxxxx' ), to_number( '00001040', 'xxxxxxxx' ),
          to_number( '00001040', 'xxxxxxxx' ), to_number( '00040040', 'xxxxxxxx' ), to_number( '10000000', 'xxxxxxxx' ), to_number( '10041000', 'xxxxxxxx' )
      );
      end if;
  --
      t_key.extend(8);
      for i in 1 .. 8
      loop
       t_key(i) := to_number( utl_raw.substr( p_key, i, 1 ), 'XX' );
      end loop;
      pclm.extend(56);
      for j in 1 .. 56
      loop
        pclm(j) := sign( bitand( t_key( trunc( pcl( j ) / 8 ) + 1 ), bytebit( bitand( pcl( j ), 7 ) + 1 ) ) );
      end loop;
      kn.extend(32);
      pcr.extend(56);
      for i in 0 .. 15
      loop
        t_m := case when p_encrypt then i else 15 - i end * 2;
        t_n := t_m + 1;
        kn(t_m+1) := 0;
        kn(t_n+1) := 0;
        for j in 0 .. 27
        loop
          t_l := j + totrot(i+1);
          if t_l < 28
          then
            pcr(j+1) := pclm( t_l + 1 );
          else
            pcr(j+1) := pclm( t_l - 28 + 1 );
          end if;
        end loop;
        for j in 28 .. 55
        loop
          t_l := j + totrot(i+1);
          if t_l < 56
          then
            pcr(j+1) := pclm( t_l + 1 );
          else
            pcr(j+1) := pclm( t_l - 28 + 1 );
          end if;
        end loop;
        for j in 0 .. 23
        loop
          if pcr( pc2( j + 1 ) + 1 ) != 0
          then
            kn( t_m + 1 ) := bitor32( kn( t_m + 1 ), bigbyte( j + 1 ) );
          end if;
          if pcr( pc2( j + 24 + 1 ) + 1 ) != 0
          then
            kn( t_n + 1 ) := bitor32( kn( t_n + 1 ), bigbyte( j + 1 ) );
          end if;
        end loop;
      end loop;
  --
      p_keys := tp_crypto();
      p_keys.extend(32);
      rawi := 1;
      knli := 1;
      for i in 0 .. 15
      loop
        raw0 := kn(rawi);
        rawi := rawi + 1;
        raw1 := kn(rawi);
        rawi := rawi + 1;
        t_tmp := bitand( raw0, to_number( 'fc0000', 'xxxxxx' ) ) * 64;
        t_tmp := bitor32( t_tmp, bitand( raw0, to_number( '0fc0', 'xxxx' ) ) * 1024 );
        t_tmp := bitor32( t_tmp, bitand( raw1, to_number( 'fc0000', 'xxxxxx' ) ) / 1024 );
        t_tmp := bitor32( t_tmp, bitand( raw1, to_number( '0fc0', 'xxxx' ) ) / 64 );
        p_keys(knli) := t_tmp;
        knli := knli + 1;
        t_tmp := bitand( raw0, to_number( '03f000', 'xxxxxx' ) ) * 4096;
        t_tmp := bitor32( t_tmp, bitand( raw0, to_number( '3f', 'xx' ) ) * 65536 );
        t_tmp := bitor32( t_tmp, bitand( raw1, to_number( '03f000', 'xxxxxx' ) ) / 16 );
        t_tmp := bitor32( t_tmp, bitand( raw1, to_number( '3f', 'xx' ) ) );
        p_keys(knli) := t_tmp;
        knli := knli + 1;
      end loop;
    end;
  --
    function des( p_block varchar2, p_keys tp_crypto )
    return varchar2
    is
      t_left  integer;
      t_right integer;
      t_tmp   integer;
      t_fval  integer;
    begin
      t_left := to_number( substr( p_block, 1, 8 ), 'XXXXXXXX' );
      t_right := to_number( substr( p_block, 9, 8 ), 'XXXXXXXX' );
      t_tmp := bitand( bitxor32( shr( t_left, 4 ), t_right ), to_number( '0f0f0f0f', 'xxxxxxxx' ) );
      t_right := bitxor32( t_right, t_tmp );
      t_left := bitxor32( t_left, shl( t_tmp, 4 ) );
      t_tmp := bitand( bitxor32( shr( t_left, 16 ), t_right ), to_number( '0000ffff', 'xxxxxxxx' ) );
      t_right := bitxor32( t_right, t_tmp );
      t_left := bitxor32( t_left, shl( t_tmp, 16 ) );
      t_tmp := bitand( bitxor32( shr( t_right, 2 ), t_left ), to_number( '33333333', 'xxxxxxxx' ) );
      t_right := bitxor32( t_right, shl( t_tmp, 2 ) );
      t_left := bitxor32( t_left, t_tmp );
      t_tmp := bitand( bitxor32( shr( t_right, 8 ), t_left ), to_number( '00ff00ff', 'xxxxxxxx' ) );
      t_right := bitxor32( t_right, shl( t_tmp, 8 ) );
      t_right := t_right * 2 + sign( bitand( t_right, 2147483648 ) );
      t_left := bitxor32( t_left, t_tmp );
      t_tmp := bitand( bitxor32( t_right , t_left ), to_number( 'aaaaaaaa', 'xxxxxxxx' ) );
      t_right := bitxor32( t_right, t_tmp );
      t_left := bitxor32( t_left, t_tmp );
      t_left := t_left * 2 + sign( bitand( t_left, 2147483648 ) );
  --
      for i in 1 .. 8
      loop
        t_tmp := bitor32( shl( t_right, 28 ), shr( t_right, 4 ) );
        t_tmp := bitxor32( t_tmp, p_keys( i * 4 - 3 ) );
        t_fval := SP7( bitand( t_tmp, 63 ) + 1 );
        t_tmp := shr( t_tmp, 8 );
        t_fval := bitor32( t_fval, SP5( bitand( t_tmp, 63 ) + 1 ) );
        t_tmp := shr( t_tmp, 8 );
        t_fval := bitor32( t_fval, SP3( bitand( t_tmp, 63 ) + 1 ) );
        t_tmp := shr( t_tmp, 8 );
        t_fval := bitor32( t_fval, SP1( bitand( t_tmp, 63 ) + 1 ) );
        t_tmp := bitxor32( t_right, p_keys( i * 4 - 2 ) );
        t_fval := bitor32( t_fval, SP8( bitand( t_tmp, 63 ) + 1 ) );
        t_tmp := shr( t_tmp, 8 );
        t_fval := bitor32( t_fval, SP6( bitand( t_tmp, 63 ) + 1 ) );
        t_tmp := shr( t_tmp, 8 );
        t_fval := bitor32( t_fval, SP4( bitand( t_tmp, 63 ) + 1 ) );
        t_tmp := shr( t_tmp, 8 );
        t_fval := bitor32( t_fval, SP2( bitand( t_tmp, 63 ) + 1 ) );
        t_left := bitxor32( t_left, t_fval );
        t_tmp := bitor32( shl( t_left, 28 ), shr( t_left, 4 ) );
        t_tmp := bitxor32( t_tmp, p_keys( i * 4 - 1 ) );
        t_fval := SP7( bitand( t_tmp, 63 ) + 1 );
        t_tmp := shr( t_tmp, 8 );
        t_fval := bitor32( t_fval, SP5( bitand( t_tmp, 63 ) + 1 ) );
        t_tmp := shr( t_tmp, 8 );
        t_fval := bitor32( t_fval, SP3( bitand( t_tmp, 63 ) + 1 ) );
        t_tmp := shr( t_tmp, 8 );
        t_fval := bitor32( t_fval, SP1( bitand( t_tmp, 63 ) + 1 ) );
        t_tmp := bitxor32( t_left, p_keys( i * 4 ) );
        t_fval := bitor32( t_fval, SP8( bitand( t_tmp, 63 ) + 1 ) );
        t_tmp := shr( t_tmp, 8 );
        t_fval := bitor32( t_fval, SP6( bitand( t_tmp, 63 ) + 1 ) );
        t_tmp := shr( t_tmp, 8 );
        t_fval := bitor32( t_fval, SP4( bitand( t_tmp, 63 ) + 1 ) );
        t_tmp := shr( t_tmp, 8 );
        t_fval := bitor32( t_fval, SP2( bitand( t_tmp, 63 ) + 1 ) );
        t_right := bitxor32( t_right, t_fval );
      end loop;
  --
      t_right := shl( t_right, 31 ) + shr( t_right, 1 );
      t_tmp := bitand( bitxor32( t_right , t_left ), to_number( 'aaaaaaaa', 'xxxxxxxx' ) );
      t_right := bitxor32( t_right, t_tmp );
      t_left := bitxor32( t_left, t_tmp );
      t_left := shl( t_left, 31 ) + shr( t_left, 1 );
      t_tmp := bitand( bitxor32( shr( t_left, 8 ), t_right ), to_number( '00ff00ff', 'xxxxxxxx' ) );
      t_right := bitxor32( t_right, t_tmp );
      t_left := bitxor32( t_left, shl( t_tmp, 8 ) );
      t_tmp := bitand( bitxor32( shr( t_left, 2 ), t_right ), to_number( '33333333', 'xxxxxxxx' ) );
      t_right := bitxor32( t_right, t_tmp );
      t_left := bitxor32( t_left, shl( t_tmp, 2 ) );
      t_tmp := bitand( bitxor32( shr( t_right, 16 ), t_left ), to_number( '0000ffff', 'xxxxxxxx' ) );
      t_right := bitxor32( t_right, shl( t_tmp, 16 ) );
      t_left := bitxor32( t_left, t_tmp );
      t_tmp := bitand( bitxor32( shr( t_right, 4 ), t_left ), to_number( '0f0f0f0f', 'xxxxxxxx' ) );
      t_right := bitxor32( t_right, shl( t_tmp, 4 ) );
      t_left := bitxor32( t_left, t_tmp );
  --
      return to_char( t_right, 'fm0XXXXXXX' ) || to_char( t_left, 'fm0XXXXXXX' );
    end;
  --
    function encrypt__rc4( src raw, key raw )
    return raw
    is
      type tp_arcfour_sbox is table of pls_integer index by pls_integer;
      type tp_arcfour is record
        (  s tp_arcfour_sbox
        ,  i pls_integer
        ,  j pls_integer
        );
      t_tmp pls_integer;
      t_s2 tp_arcfour_sbox;
      t_arcfour tp_arcfour;
      t_encr raw(32767);
    begin
      for  i in 0 .. 255
      loop
        t_arcfour.s(i) :=  i;
      end  loop;
      for  i in 0 .. 255
      loop
        t_s2(i) := to_number( utl_raw.substr( key, mod( i, utl_raw.length( key ) ) + 1, 1 ), 'XX' );
      end  loop;
      t_arcfour.j  := 0;
      for  i in 0 .. 255
      loop
        t_arcfour.j := mod( t_arcfour.j +  t_arcfour.s(i) + t_s2(i), 256 );
        t_tmp := t_arcfour.s(i);
        t_arcfour.s(i) :=  t_arcfour.s( t_arcfour.j );
        t_arcfour.s( t_arcfour.j ) := t_tmp;
      end  loop;
      t_arcfour.i  := 0;
      t_arcfour.j  := 0;
  --
      for  i in 1 .. utl_raw.length( src )
      loop
        t_arcfour.i := bitand( t_arcfour.i + 1, 255 );
        t_arcfour.j := bitand( t_arcfour.j + t_arcfour.s(  t_arcfour.i ), 255 );
        t_tmp := t_arcfour.s( t_arcfour.i  );
        t_arcfour.s( t_arcfour.i ) := t_arcfour.s( t_arcfour.j );
        t_arcfour.s( t_arcfour.j ) := t_tmp;
        t_encr := utl_raw.concat( t_encr
                                , to_char( t_arcfour.s( bitand( t_arcfour.s( t_arcfour.i ) + t_arcfour.s( t_arcfour.j ), 255 ) ), 'fm0x' )
                                );
      end  loop;
      return utl_raw.bit_xor( src, t_encr );
    end;
  --
    function encrypt( src raw, typ pls_integer, key raw, iv raw := null )
    return raw
    is
      t_keys tp_crypto;
      t_keys2 tp_crypto;
      t_keys3 tp_crypto;
      t_encrypt_key tp_aes_tab;
      t_idx pls_integer;
      t_len pls_integer;
      t_tmp varchar2(32766);
      t_tmp2 varchar2(32766);
      t_encr raw(32767);
      t_plain raw(32767);
      t_padding raw(65);
      t_pad pls_integer;
      t_iv raw(64);
      t_raw raw(64);
      t_bs pls_integer := 8;
      t_bs2 pls_integer;
      function encr( p raw )
      return raw
      is
        tmp raw(100);
      begin
        case bitand( typ, 15 )
          when gc_encrypt_3des then
            tmp := des( des( des( p, t_keys ), t_keys2 ), t_keys3 );
          when gc_encrypt_des then
            tmp := des( p, t_keys );
          when gc_encrypt_3des_2key then
            tmp := des( des( des( p, t_keys ), t_keys2 ), t_keys3 );
          when gc_encrypt_aes then
            tmp := aes_encrypt( p, utl_raw.length( key ), t_encrypt_key );
          when gc_encrypt_aes128 then
            tmp := aes_encrypt( p, 16, t_encrypt_key );
          when gc_encrypt_aes192 then
            tmp := aes_encrypt( p, 24, t_encrypt_key );
          when gc_encrypt_aes256 then
            tmp := aes_encrypt( p, 32, t_encrypt_key );
          else
            tmp := p;
        end case;
        return tmp;
      end;
    begin
      if bitand( typ, 255 ) = gc_ENCRYPT_RC4
      then
        return encrypt__rc4( src, key );
      end if;
      case bitand( typ, 15 )
        when gc_encrypt_3des then
          deskey( utl_raw.substr( key, 1, 8 ), t_keys, true );
          deskey( utl_raw.substr( key, 9, 8 ), t_keys2, false );
          deskey( utl_raw.substr( key, 17, 8 ), t_keys3, true );
        when gc_encrypt_des then
          deskey( utl_raw.substr( key, 1, 8 ), t_keys, true );
        when gc_encrypt_3des_2key then
          deskey( utl_raw.substr( key, 1, 8 ), t_keys, true );
          deskey( utl_raw.substr( key, 9, 8 ), t_keys2, false );
          t_keys3 := t_keys;
        when gc_encrypt_aes then
          t_bs := 16;
          aes_encrypt_key( key, t_encrypt_key  );
        when gc_encrypt_aes128 then
          t_bs := 16;
          aes_encrypt_key( key, t_encrypt_key  );
        when gc_encrypt_aes192 then
          t_bs := 16;
          aes_encrypt_key( key, t_encrypt_key  );
        when gc_encrypt_aes256 then
          t_bs := 16;
          aes_encrypt_key( key, t_encrypt_key  );
        else
          null;
      end case;
      case bitand( typ, 61440 )
        when gc_PAD_NONE then
          t_pad := mod( utl_raw.length( src ), t_bs );
          if t_pad > 0
          then
            t_padding := utl_raw.copies( '00', t_bs - t_pad );
          end if;
        when gc_pad_pkcs5 then
          t_pad := t_bs - mod( utl_raw.length( src ), t_bs );
          t_padding := utl_raw.copies( to_char( t_pad, 'fm0X' ), t_pad );
        when gc_pad_oneandzeroes then -- OneAndZeroes Padding, ISO/IEC 7816-4
          t_pad := t_bs - 1 - mod( utl_raw.length( src ), t_bs );
          if t_pad = 0
          then
            t_padding := '80';
          else
            t_padding := utl_raw.concat( '80', utl_raw.copies( '00', t_pad ) );
          end if;
        when gc_pad_ansi_x923 then -- ANSI X.923
          t_pad := t_bs - 1 - mod( utl_raw.length( src ), t_bs );
          if t_pad = 0
          then
            t_pad := t_bs;
          end if;
          t_padding := utl_raw.concat( utl_raw.copies( '00', t_pad ), to_char( t_pad, 'fm0X' ) );
        when gc_PAD_ZERO then -- zero padding
          t_pad := mod( utl_raw.length( src ), t_bs );
          if t_pad > 0
          then
            t_padding := utl_raw.copies( '00', t_bs - t_pad );
          end if;
        when gc_PAD_ORCL then -- zero padding
          t_pad := mod( utl_raw.length( src ), t_bs );
          if t_pad > 0
          then
            t_padding := utl_raw.copies( '00', t_bs - t_pad );
          end if;
        else
          null;
      end case;
      t_bs2 := t_bs * 2;
      t_plain := utl_raw.concat( src, t_padding );
      t_idx := 1;
      t_len := utl_raw.length( t_plain );
      t_iv := coalesce( iv, utl_raw.copies( '0', t_bs ) );
      while t_idx <= t_len
      loop
        t_tmp := rawtohex( utl_raw.substr( t_plain, t_idx, least( 16376, t_len - t_idx + 1 ) ) );
        t_idx := t_idx + 16376;
        t_tmp2 := null;
        for i in 0 .. trunc( length( t_tmp ) / t_bs2 ) - 1
        loop
          case bitand( typ, 3840 )
            when gc_chain_cbc then
              t_raw := utl_raw.bit_xor( substr( t_tmp, i * t_bs2 + 1, t_bs2 ), t_iv );
              t_raw := encr( t_raw );
              t_iv := t_raw;
            when gc_chain_cfb then
              t_iv := encr( t_iv );
              t_raw := utl_raw.bit_xor( substr( t_tmp, i * t_bs2 + 1, t_bs2 ), t_iv );
              t_iv := t_raw;
            when gc_chain_ecb then
              t_raw := encr( substr( t_tmp, i * t_bs2 + 1, t_bs2 ) );
            when gc_chain_ofb then
  $IF DBMS_DB_VERSION.VER_LE_10 $THEN
              t_raw := encr( substr( t_tmp, i * t_bs2 + 1, t_bs2 ) );
  $ELSIF DBMS_DB_VERSION.VER_LE_11 $THEN
              t_raw := encr( substr( t_tmp, i * t_bs2 + 1, t_bs2 ) );
  $ELSE
              t_iv := encr( t_iv );
              t_raw := utl_raw.bit_xor( substr( t_tmp, i * t_bs2 + 1, t_bs2 ), t_iv );
  $end
            when gc_CHAIN_OFB_REAL then
              t_iv := encr( t_iv );
              t_raw := utl_raw.bit_xor( substr( t_tmp, i * t_bs2 + 1, t_bs2 ), t_iv );
            else
              null;
          end case;
          t_tmp2 := t_tmp2 || t_raw;
        end loop;
        t_encr := utl_raw.concat( t_encr, hextoraw( t_tmp2 ) );
      end loop;
      case bitand( typ, 61440 )
        when gc_PAD_NONE then
          t_encr := utl_raw.substr( t_encr, 1, utl_raw.length( src ) );
        when gc_PAD_ORCL then
          t_encr := utl_raw.concat( t_encr, to_char( t_bs - mod( utl_raw.length( src ) - 1, t_bs ), 'fm0X' ) );
        else
          null;
      end case;
      return t_encr;
    end;
  --
    function decrypt( src raw, typ pls_integer, key raw, iv raw := null )
    return raw
    is
      t_keys tp_crypto;
      t_keys2 tp_crypto;
      t_keys3 tp_crypto;
      t_decrypt_key tp_aes_tab;
      t_idx pls_integer;
      t_len pls_integer;
      t_tmp varchar2(32766);
      t_tmp2 varchar2(32766);
      t_decr raw(32767);
      t_pad pls_integer;
      t_iv raw(64);
      t_raw raw(64);
      t_bs pls_integer := 8;
      t_bs2 pls_integer;
      t_fb boolean;
      function decr( p raw )
      return raw
      is
        tmp raw(100);
      begin
        case bitand( typ, 15 )
          when gc_encrypt_3des then
            tmp := des( des( des( p, t_keys3 ), t_keys2 ), t_keys );
          when gc_encrypt_des then
            tmp := des( p, t_keys );
          when gc_encrypt_3des_2key then
            tmp := des( des( des( p, t_keys3 ), t_keys2 ), t_keys );
          when gc_encrypt_aes then
            tmp := aes_decrypt( p, utl_raw.length( key ), t_decrypt_key );
          when gc_encrypt_aes128 then
            tmp := aes_decrypt( p, 16, t_decrypt_key );
          when gc_encrypt_aes192 then
            tmp := aes_decrypt( p, 24, t_decrypt_key );
          when gc_encrypt_aes256 then
            tmp := aes_decrypt( p, 32, t_decrypt_key );
          else
            tmp := p;
        end case;
        return tmp;
      end;
    begin
      if bitand( typ, 255 ) = gc_ENCRYPT_RC4
      then
        return encrypt__rc4( src, key );
      end if;
  $if dbms_db_version.ver_le_10 $then
      t_fb := bitand( typ, 3840 ) in ( gc_CHAIN_CFB, gc_CHAIN_OFB_REAL );
  $elsif dbms_db_version.ver_le_11 $then
      t_fb := bitand( typ, 3840 ) in ( gc_CHAIN_CFB, gc_CHAIN_OFB_REAL );
  $else
      t_fb := bitand( typ, 3840 ) in ( gc_CHAIN_CFB, gc_CHAIN_OFB, gc_CHAIN_OFB_REAL );
  $END
      case bitand( typ, 15 )
        when gc_encrypt_3des then
          deskey( utl_raw.substr( key, 1, 8 ), t_keys, t_fb );
          deskey( utl_raw.substr( key, 9, 8 ), t_keys2, not t_fb );
          deskey( utl_raw.substr( key, 17, 8 ), t_keys3, t_fb );
        when gc_encrypt_des then
          deskey( utl_raw.substr( key, 1, 8 ), t_keys, t_fb );
        when gc_encrypt_3des_2key then
          deskey( utl_raw.substr( key, 1, 8 ), t_keys, t_fb );
          deskey( utl_raw.substr( key, 9, 8 ), t_keys2, not t_fb );
          t_keys3 := t_keys;
        when gc_encrypt_aes then
          t_bs := 16;
          aes_decrypt_key( key, t_decrypt_key  );
        when gc_encrypt_aes128 then
          t_bs := 16;
          aes_decrypt_key( key, t_decrypt_key  );
        when gc_encrypt_aes192 then
          t_bs := 16;
          aes_decrypt_key( key, t_decrypt_key  );
        when gc_encrypt_aes256 then
          t_bs := 16;
          aes_decrypt_key( key, t_decrypt_key  );
        else
          null;
      end case;
      t_idx := 1;
      t_len := utl_raw.length( src );
      t_iv := coalesce( iv, utl_raw.copies( '0', t_bs ) );
      t_bs2 := t_bs * 2;
      while t_idx <= t_len
      loop
        t_tmp := utl_raw.substr( src, t_idx, least( 16376, t_len - t_idx + 1 ) );
        if (   bitand( typ, 61440 ) = gc_PAD_NONE
           and mod( utl_raw.length( t_tmp ), t_bs ) != 0
           )
        then
          t_tmp := utl_raw.concat( t_tmp, utl_raw.copies( '00', t_bs - mod( utl_raw.length( t_tmp ), t_bs ) ) );
        end if;
        t_idx := t_idx + 16376;
        t_tmp2 := null;
        for i in 0 .. length( t_tmp ) / t_bs2 - 1
        loop
          case bitand( typ, 3840 )
           when gc_CHAIN_CBC then
              t_raw := decr( substr( t_tmp, i * t_bs2 + 1, t_bs2 ) );
              t_raw := utl_raw.bit_xor( t_raw, t_iv );
              t_iv := substr( t_tmp, i * t_bs2 + 1, t_bs2 );
            when gc_CHAIN_CFB then
              t_raw := decr( t_iv );
              t_iv := substr( t_tmp, i * t_bs2 + 1, t_bs2 );
              t_raw := utl_raw.bit_xor( t_raw, t_iv );
            when gc_CHAIN_OFB then
  $IF DBMS_DB_VERSION.VER_LE_10 $THEN
              t_raw := decr( substr( t_tmp, i * t_bs2 + 1, t_bs2 ) );
  $ELSIF DBMS_DB_VERSION.VER_LE_11 $THEN
              t_raw := decr( substr( t_tmp, i * t_bs2 + 1, t_bs2 ) );
  $ELSE
              t_iv := decr( t_iv );
              t_raw := utl_raw.bit_xor( substr( t_tmp, i * t_bs2 + 1, t_bs2 ), t_iv );
  $end
            when gc_CHAIN_OFB_REAL then
              t_iv := decr( t_iv );
              t_raw := utl_raw.bit_xor( substr( t_tmp, i * t_bs2 + 1, t_bs2 ), t_iv );
            when gc_CHAIN_ECB then
              t_raw := decr( substr( t_tmp, i * t_bs2 + 1, t_bs2 ) );
          end case;
          t_tmp2 := t_tmp2 || t_raw;
        end loop;
        t_decr := utl_raw.concat( t_decr, hextoraw( t_tmp2 ) );
      end loop;
      case bitand( typ, 61440 )
        when gc_PAD_PKCS5 then
          t_pad := to_number( utl_raw.substr( t_decr, -1 ), 'XX' );
          t_pad := utl_raw.length( t_decr ) - t_pad;
          t_decr := utl_raw.substr( t_decr, 1, t_pad );
        when gc_PAD_OneAndZeroes then -- OneAndZeroes Padding, ISO/IEC 7816-4
          t_pad := length( t_tmp2 ) - instr( t_tmp2, '80', -1 ) + 1;
          t_pad := utl_raw.length( t_decr ) - t_pad / 2;
          t_decr := utl_raw.substr( t_decr, 1, t_pad );
        when gc_PAD_ANSI_X923 then -- ANSI X.923
          t_pad := to_number( utl_raw.substr( t_decr, -1 ), 'XX' );
          t_pad := utl_raw.length( t_decr ) - t_pad - 1;
          t_decr := utl_raw.substr( t_decr, 1, t_pad );
        when gc_PAD_ZERO then -- zero padding
          t_pad := length( t_tmp2 ) - length( rtrim( t_tmp2, '0' ) );
          t_pad := trunc( t_pad / 2 );
          if t_pad > 0
          then
            t_pad := utl_raw.length( t_decr ) - t_pad;
            t_decr := utl_raw.substr( t_decr, 1, t_pad );
          end if;
        when gc_PAD_ORCL then -- zero padding
          t_pad := length( t_tmp2 ) - length( rtrim( t_tmp2, '0' ) );
          t_pad := trunc( t_pad / 2 );
          if t_pad > 0
          then
            t_pad := utl_raw.length( t_decr ) - t_pad;
            t_decr := utl_raw.substr( t_decr, 1, t_pad );
          end if;
        when gc_PAD_NONE then
          t_decr := utl_raw.substr( t_decr, 1, t_len );
        else
          null;
      end case;
      return t_decr;
    end;
  --

end oos_util_crypto;
/
