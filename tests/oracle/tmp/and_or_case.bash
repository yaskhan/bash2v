false && echo no
false || echo yes
true && echo ok
true || echo no
if false || true; then
echo cond
fi