#############################################################################
##
#W  HelpBookHandler.g                GAPDoc                      Frank Lübeck
##
##
#Y  Copyright (C)  2000,  Frank Lübeck,  Lehrstuhl D für Mathematik,  
#Y  RWTH Aachen
##  
##  This file contains the HELP_BOOK_HANDLER functions for the GapDocGAP
##  format.  This  is  the  interface  between  the  converter  programs
##  contained in the GAPDoc package and GAP's help system.
## 

HELPBOOKINFOSIXTMP := 0;

##  <#GAPDoc Label="SetGAPDocHTMLStyle">
##  <ManSection >
##  <Func Arg="[style1[, style2] ...]" Name="SetGAPDocHTMLStyle" />
##  <Returns>nothing</Returns>
##  <Description>
##  This utility function is for readers  of the HTML   version of &GAP;
##  manuals which  are generated by  the &GAPDoc; package. It  allows to
##  configure  the display style of the manuals. This will only have an
##  effect if you are using a browser that supports
##  <Package>javascript</Package>.
##  There  is a  default which  can be  reset by  calling this  function
##  without argument. <P/>
##  
##  The arguments <A>style1</A> and so on must be strings. You can find out
##  about the valid strings by following the <B>[Style]</B> link on top
##  of any manual page. (Going back to the original page, its address has a
##  setting for <C>GAPDocStyle</C> which is the list of strings, separated
##  by commas, you want to use here.)
##  
##  <Example>
##  gap> # show/hide subsections in tables on contents only after click,
##  gap> # and don't use colors in GAP examples
##  gap> SetGAPDocHTMLStyle("toggless", "nocolorprompt");
##  </Example>
##  </Description>
##  </ManSection>
##  <#/GAPDoc>
BindGlobal("SetGAPDocHTMLStyle", function(arg)
  if Length(arg) = 0 then
    GAPInfo.UserPreferences.GAPDocHTMLStyle := "default";
  else
    GAPInfo.UserPreferences.GAPDocHTMLStyle := 
                                      JoinStringsWithSeparator(arg, ",");
  fi;
end);

atomic readwrite HELP_REGION do

HELP_BOOK_HANDLER.GapDocGAP := MigrateObj(rec(),HELP_REGION);

##  
##  The  .entries info in the GapDocGAP  six-format has  entries of form 
##  
##      [ showstring,  
##        sectionstring,  (allows searching of section numbers, like: "1.3-4")
##        [chapnr, secnr, subsecnr], 
##        linenr  (for "text" format), 
##        pagenr (for .dvi, .pdf-formats),
##        idstring (for a link L.<idstring> in PDF file,
##        searchstring (simplified lowercased version of <showstring>)
##      ]
##  

# helper to set the text theme
HELP_BOOK_HANDLER.GapDocGAP.setTextTheme := function()
  if IsString(GAPInfo.UserPreferences.TextTheme) then
    GAPInfo.UserPreferences.TextTheme := [ GAPInfo.UserPreferences.TextTheme ];
  fi;
  if GAPInfo.UserPreferences.TextTheme = ["default"] then
    if not IsBound(GAPInfo.UserPreferences.UseColorsInTerminal) or 
         GAPInfo.UserPreferences.UseColorsInTerminal <> true then
      SetGAPDocTextTheme("none");
    else
      SetGAPDocTextTheme(rec());
    fi;
  else
    CallFuncList(SetGAPDocTextTheme, GAPInfo.UserPreferences.TextTheme);
  fi;
end;
HELP_BOOK_HANDLER.GapDocGAP.setTextTheme();

# helper function for showing matches in current text theme
HELP_BOOK_HANDLER.GapDocGAP.apptheme := function(res, theme)
  local a;
  if not IsBound(res.theme) or res.theme <> theme then
    atomic readwrite res do
      for a in res.entries do
        a[1] := SubstituteEscapeSequences(a[8], theme);
      od;
      res.theme := ShallowCopy(theme);
    od;  
  fi;
end;


# set HTML style from gap.ini file
HELP_BOOK_HANDLER.GapDocGAP.f := function()
  if IsString(GAPInfo.UserPreferences.HTMLStyle) then
    GAPInfo.UserPreferences.HTMLStyle := [GAPInfo.UserPreferences.HTMLStyle];
  fi;
  CallFuncList(SetGAPDocHTMLStyle, GAPInfo.UserPreferences.HTMLStyle);
end;
HELP_BOOK_HANDLER.GapDocGAP.f();
Unbind(HELP_BOOK_HANDLER.GapDocGAP.f);

HELP_BOOK_HANDLER.GapDocGAP.ReadSix := function(stream)
  local fname, res, bname, nam, a, apptheme;
  # our .six file is directly GAP-readable
  fname := ShallowCopy(stream![2]);
  #Read(stream);
  # this seems better on NFS file systems ...
  CloseStream(stream);
  Read(fname);
  res := HELPBOOKINFOSIXTMP;
  Unbind(HELPBOOKINFOSIXTMP);
  
  # adjust search strings to current text theme, save original in position 8
  for a in res.entries do
    a[8] := a[1];
  od;
##    HELP_BOOK_HANDLER.GapDocGAP.setTextTheme();
  HELP_BOOK_HANDLER.GapDocGAP.apptheme(res, GAPDocTextTheme);
  
  # in position 6 of each entry we put the corresponding search string
  for a in res.entries do
    if not IsBound(a[6]) then
      a[6] := SIMPLE_STRING(StripEscapeSequences(a[1]));
      NormalizeWhitespace(a[6]);
    fi;
  od;
  
  # We  check the current availability of the different
  # formats. And we add the help directory.
  res.handler := "GapDocGAP";
  res.directory := Directory(fname{[1..Length(fname)-10]});
  res.types := ["text"];
  # check if  .dvi and .pdf files and HTML-version available
  bname := fname{[1..Length(fname)-4]};
  nam := Concatenation(bname, ".dvi");
  if IsExistingFile(nam) then
    res.dvifile := nam;
    Add(res.types, "dvi");
  fi;
  nam := Concatenation(bname, ".pdf");
  if IsExistingFile(nam) then
    res.pdffile := nam;
    Add(res.types, "pdf");
  fi;
  nam := Concatenation(bname{[1..Length(bname)-6]}, "chap0.html");
  if IsExistingFile(nam) then
    Add(res.types, "url");
    Add(res.types, "url-text");
  fi;
  nam := Concatenation(bname{[1..Length(bname)-6]}, "chap0_sym.html");
  if IsExistingFile(nam) then
    Add(res.types, "url");
    Add(res.types, "url-sym");
  fi;
  nam := Concatenation(bname{[1..Length(bname)-6]}, "chap0_mml.xml");
  if IsExistingFile(nam) then
    Add(res.types, "url");
    Add(res.types, "url-mml");
  fi;
  nam := Concatenation(bname{[1..Length(bname)-6]}, "chap0_mj.html");
  if IsExistingFile(nam) then
    Add(res.types, "url");
    Add(res.types, "url-mj");
  fi;
  
  return res;
end;
Unbind(HELPBOOKINFOSIXTMP);

# Our help output format contains the table of contents,
# so we just delegate.
HELP_BOOK_HANDLER.GapDocGAP.ShowChapters := function(book)
  local   info, match;
  info := HELP_BOOK_INFO(book);
  match := Concatenation(HELP_BOOK_HANDLER.GapDocGAP.SearchMatches(book, 
                                            "table of contents", true))[1];
  return HELP_BOOK_HANDLER.GapDocGAP.HelpData(info, match, "text");
end;

HELP_BOOK_HANDLER.GapDocGAP.ShowSections := 
                                 HELP_BOOK_HANDLER.GapDocGAP.ShowChapters;

#  very similar to the .default handler, but we allow search for
#  (sub-)section numbers as well
HELP_BOOK_HANDLER.GapDocGAP.SearchMatches := function (book, topic, frombegin)
  local   info,  exact,  match,  i;
  
  info := HELP_BOOK_INFO(book);
  exact := [];
  match := [];
  for i in [1..Length(info.entries)] do
    if topic=info.entries[i][6] or topic=info.entries[i][2] then
      Add(exact, i);
    elif frombegin = true then
      if MATCH_BEGIN(info.entries[i][6], topic) or 
         MATCH_BEGIN(info.entries[i][2], topic) then
        Add(match, i);
      fi;
    else
      if IS_SUBSTRING(info.entries[i][6], topic) then
        Add(match, i);
      fi;
    fi;
  od;
##    HELP_BOOK_HANDLER.GapDocGAP.setTextTheme();
  HELP_BOOK_HANDLER.GapDocGAP.apptheme(info, GAPDocTextTheme);

  return [exact, match];
end;

##  The data are all easy to get.
if not IsBound(BROWSER_CAP) then
  BROWSER_CAP := [];
fi;
HELP_BOOK_HANDLER.GapDocGAP.HelpData := function(book, entrynr, type)
  local info, a, fname, str, formatted, enc, outenc, sline, pos, 
        tmp, ext, label, res;
  
  info := HELP_BOOK_INFO(book);
  # we handle the special type "ref" for cross references first
  if type = "ref" then
    a := HELP_BOOK_HANDLER.HelpDataRef(info, entrynr);
    a[1] := StripEscapeSequences(a[1]);
    return a;
  fi;
  
  a := info.entries[entrynr];
  
  # section number info
  if type = "secnr" then
    return a{[3,2]};
  fi;

  if not type in info.types then 
    return fail;
  fi;
  
  if type = "text" then
    fname := Filename(info.directory, Concatenation("chap", String(a[3][1]),
             ".txt"));
    str := StringFile(fname);
    if str = fail then
      return rec(lines := Concatenation("Sorry, file '", fname, "' seems to ",
                 "be corrupted.\n"), formatted := true);
    fi;
    # maybe change encoding
    if IsBound(info.encoding) then
      enc := info.encoding;
    else
      # from older versions, so latin1
      enc := "ISO-8859-1";
    fi;
    if IsBound(GAPInfo.TermEncoding) then
      outenc := GAPInfo.TermEncoding;
    else
      outenc := "ISO-8859-1";
    fi;
    enc := UNICODE_RECODE.NormalizedEncodings.(enc);
    outenc := UNICODE_RECODE.NormalizedEncodings.(outenc);
    if enc <> outenc then
      str := Unicode(str, enc);
      if outenc = "ISO-8859-1" then
        str := SimplifiedUnicodeString(str, "latin1");
      elif outenc = "ANSI_X3.4-1968" then
        str := SimplifiedUnicodeString(str, "ascii");
      fi;
      str := Encode(str, outenc);
    fi;
    sline := a[4];
    # set the text theme
##      HELP_BOOK_HANDLER.GapDocGAP.setTextTheme();
    # substitute pseudo escape sequences via GAPDocTextTheme
    # split into two pieces to find new start line
    pos := PositionLinenumber(str, sline);
    tmp := SubstituteEscapeSequences(str{[1..pos-1]}, GAPDocTextTheme);
    str := SubstituteEscapeSequences(str{[pos..Length(str)]}, 
                                                      GAPDocTextTheme);
    sline := NumberOfLines(tmp)+1;
    str := Concatenation(tmp, str);
    return rec(lines := str, formatted := true, start := sline);
  fi;
  
  if type = "url" and "url" in info.types then
##      # check preferred HTML version/extension
##      if not IsBound(BROWSER_CAP) then
##        BROWSER_CAP := [];
##      fi;
##      if "MathML" in BROWSER_CAP and "url-mml" in info.types then
##        ext := "_mml.xml";
##      elif ("MathML" in BROWSER_CAP or "Symbol" in BROWSER_CAP) and
##            "url-sym" in info.types then
##        ext := "_sym.html";
##      elif "url-text" in info.types then
##        ext := ".html";
##      else
##        return fail;
##      fi;
    if IsBound(GAPInfo.UserPreferences) and 
               IsBound(GAPInfo.UserPreferences.UseMathJax) and
               GAPInfo.UserPreferences.UseMathJax = true and
               "url-mj" in info.types then
      ext := "_mj.html";
    elif "url-text" in info.types then
      ext := ".html";
    else
      return fail;
    fi;
    if GAPInfo.UserPreferences.GAPDocHTMLStyle <> "default" then
      ext := Concatenation(ext, "?GAPDocStyle=", 
                                 GAPInfo.UserPreferences.GAPDocHTMLStyle);
    fi;
    fname := Filename(info.directory, Concatenation("chap",
                       String(a[3][1]), ext));
    if IsBound(a[7]) then
      label := a[7];
    else
      # from older version of GAPDoc
      label := Concatenation("s", String(a[3][2]),
                     "ss", String(a[3][3]));
    fi;
    # ??? return Concatenation("file:", fname, label);
    return Concatenation("", fname, "#", label);
  fi;
  
  if type = "dvi" then
    return rec(file := info.dvifile, page := a[5]);
  fi;
  
  if type = "pdf" then
    res := rec(file := info.pdffile, page := a[5]);
    if IsBound(a[7]) then
      res.label := Concatenation("L.", a[7]);
    fi;
    return res;
  fi;

  return fail;
end;

##  cache list of chapter numbers, but only if we need them
HELP_BOOK_HANDLER.GapDocGAP.ChapNumbers := function(info)
  local l, sp;
  if not IsBound(info.ChapNumbers) then
    l := Set(List(info.entries,a->a[3][1]));
    sp := IntersectionSet(l, ["Bib", "Ind"]);
    l := Difference(l, sp);
    Append(l, sp);
    info.ChapNumbers := l;
  fi;
end;

##  for ?<<,  ?>>,  ?<  and  ?>
HELP_BOOK_HANDLER.GapDocGAP.MatchPrevChap := function(book, entrynr)
  local info, chnums, ent, cnr, new, nr;
  info := HELP_BOOK_INFO(book);
  HELP_BOOK_HANDLER.GapDocGAP.ChapNumbers(info);
  chnums := info.ChapNumbers;
  ent := info.entries;
  cnr := ent[entrynr][3];
  if cnr[2] <> 0 or cnr[3] <> 0 or cnr[1] = chnums[1] then
    new := [cnr[1], 0, 0];
  else
    new := [chnums[Position(chnums, cnr[1])-1], 0, 0];
  fi;
  nr := First([1..Length(ent)], i-> ent[i][3] = new);
  if nr = fail then
    # return current
    nr := entrynr;
  fi;
  return [info, nr];
end;

HELP_BOOK_HANDLER.GapDocGAP.MatchNextChap := function(book, entrynr)
  local info, chnums, ent, cnr, new, nr;
  info := HELP_BOOK_INFO(book);
  HELP_BOOK_HANDLER.GapDocGAP.ChapNumbers(info);
  chnums := info.ChapNumbers;
  ent := info.entries;
  cnr := ent[entrynr][3];
  if cnr[1] = chnums[Length(chnums)] then
    new := [cnr[1], 0, 0];
  else
    new := [chnums[Position(chnums, cnr[1])+1], 0, 0];
  fi;
  nr := First([1..Length(ent)], i-> ent[i][3] = new);
  if nr = fail then
    # return current
    nr := entrynr;
  fi;
  return [info, nr];
end;

HELP_BOOK_HANDLER.GapDocGAP.MatchPrev := function(book, entrynr)
  local   info,  ent,  old,  new,  nr,  i;
  info := HELP_BOOK_INFO(book);
  ent := info.entries;
  old := ent[entrynr][3];
  new := [-1,0,0];
  nr := entrynr;
  for i in [1..Length(ent)] do
    if ent[i][3] < old and ent[i][3] > new and 
       not ent[i][3][1] in ["Bib", "Ind"] then
      new := ent[i][3];
      nr := i;
    fi;
  od;
  return [info, nr];
end;

HELP_BOOK_HANDLER.GapDocGAP.MatchNext := function(book, entrynr)
  local   info,  ent,  old,  new,  nr,  i;
  info := HELP_BOOK_INFO(book);
  ent := info.entries;
  old := ent[entrynr][3];
  new := ["ZZZ",0,0];
  nr := entrynr;
  for i in [1..Length(ent)] do
    if ent[i][3] > old and ent[i][3] < new and 
       not ent[i][3][1] in ["Bib", "Ind"] then
      new := ent[i][3];
      nr := i;
    fi;
  od;
  return [info, nr];
end;

od;

