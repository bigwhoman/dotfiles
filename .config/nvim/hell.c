#include <stdio.h>

// TODO:add better comments here

struct a {
  int a;
  char *c;
};

int main() {
  for (int i = 0; i < 5; i++)
    for (int j = 0; j < 5; j++)
      printf("hello");
  return 0;
}

int how(int a) { return a + 5; }
