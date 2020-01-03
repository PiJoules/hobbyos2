void some_func() {
  *((char*)0xb8000) = 'X';
}

extern "C" {

void kmain() {
  some_func();

  while (1) {}  // Let's just hang here for a while.
}

}
