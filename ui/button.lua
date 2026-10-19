local callback;
function configure(text, fn)
  setText(text); callback = fn;
end
function onButtonPress()
  if callback then callback(); end
end
