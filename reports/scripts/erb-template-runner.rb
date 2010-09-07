if $libraryScript
  # load in the library
  srcProp = $libraryScript.otClass().getProperty("src")
  srcValue = $libraryScript.otGet(srcProp)  
  eval(Java::JavaLang::String.new($libraryScript.src).to_s, nil, srcValue.getBlobURL().toExternalForm())
end

def getText
  @otrunk = $viewContext.getViewService(OTrunk.java_class);
  render($template)
end
