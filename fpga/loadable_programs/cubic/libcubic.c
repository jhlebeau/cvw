/* BEEBS cubic benchmark

   This version, copyright (C) 2013-2019 Embecosm Limited and University of
   Bristol

   Contributor: James Pallister <james.pallister@bristol.ac.uk>
   Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

   This file is part of Embench and was formerly part of the Bristol/Embecosm
   Embedded Benchmark Suite.

   SPDX-License-Identifier: GPL-3.0-or-later

   The original code is from http://www.snippets.org/. */

#include <math.h>

#include "snipmath.h"

static double
fabs_beebs (double x)
{
  return (x < 0.0) ? -x : x;
}

static double
sqrt_beebs (double x)
{
  double guess;
  int i;

  if (x <= 0.0)
    return 0.0;

  guess = (x > 1.0) ? x : 1.0;
  for (i = 0; i < 24; i++)
    guess = 0.5 * (guess + x / guess);

  return guess;
}

static double
cubic_eval (double a, double b, double c, double d, double x)
{
  return ((a * x + b) * x + c) * x + d;
}

static double
root_bound (double a, double b, double c, double d)
{
  double max_coeff = fabs_beebs (b);

  if (fabs_beebs (c) > max_coeff)
    max_coeff = fabs_beebs (c);
  if (fabs_beebs (d) > max_coeff)
    max_coeff = fabs_beebs (d);

  return 1.0 + max_coeff / fabs_beebs (a);
}

static double
bisection_root (double a, double b, double c, double d, double left, double right)
{
  double f_left = cubic_eval (a, b, c, d, left);
  double mid = left;
  int i;

  for (i = 0; i < 80; i++)
    {
      double f_mid;

      mid = 0.5 * (left + right);
      f_mid = cubic_eval (a, b, c, d, mid);

      if (fabs_beebs (f_mid) < 1.0e-15 || fabs_beebs (right - left) < 1.0e-14)
        break;

      if ((f_left < 0.0 && f_mid < 0.0) || (f_left > 0.0 && f_mid > 0.0))
        {
          left = mid;
          f_left = f_mid;
        }
      else
        {
          right = mid;
        }
    }

  return mid;
}

void
SolveCubic (double a, double b, double c, double d, int *solutions, double *x)
{
  double discriminant = 4.0 * b * b - 12.0 * a * c;
  double bound = root_bound (a, b, c, d);

  if (discriminant <= 0.0)
    {
      *solutions = 1;
      x[0] = bisection_root (a, b, c, d, -bound, bound);
      return;
    }

  {
    double sqrt_disc = sqrt_beebs (discriminant);
    double turning0 = (-2.0 * b - sqrt_disc) / (6.0 * a);
    double turning1 = (-2.0 * b + sqrt_disc) / (6.0 * a);
    double f0 = cubic_eval (a, b, c, d, turning0);
    double f1 = cubic_eval (a, b, c, d, turning1);

    if (((f0 < 0.0) && (f1 < 0.0)) || ((f0 > 0.0) && (f1 > 0.0)))
      {
        *solutions = 1;
        x[0] = bisection_root (a, b, c, d, -bound, bound);
        return;
      }

    *solutions = 3;
    x[0] = bisection_root (a, b, c, d, -bound, turning0);
    x[1] = bisection_root (a, b, c, d, turning1, bound);
    x[2] = bisection_root (a, b, c, d, turning0, turning1);
  }
}

/* vim: set ts=3 sw=3 et: */
