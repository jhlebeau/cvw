#include <math.h>
#include <stdint.h>

#include "beebsc.h"
#include "embench_common.h"

#define NBODY_LOCAL_SCALE_FACTOR 1
#define NBODY_PI 3.141592653589793
#define SOLAR_MASS (4 * NBODY_PI * NBODY_PI)
#define DAYS_PER_YEAR 365.24

struct nbody_body
{
  double x[3], fill, v[3], mass;
};

static struct nbody_body solar_bodies[] = {
  {{0., 0., 0.}, 0., {0., 0., 0.}, SOLAR_MASS},
  {{4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01},
   0.,
   {1.66007664274403694e-03 * DAYS_PER_YEAR,
    7.69901118419740425e-03 * DAYS_PER_YEAR,
    -6.90460016972063023e-05 * DAYS_PER_YEAR},
   9.54791938424326609e-04 * SOLAR_MASS},
  {{8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01},
   0.,
   {-2.76742510726862411e-03 * DAYS_PER_YEAR,
    4.99852801234917238e-03 * DAYS_PER_YEAR,
    2.30417297573763929e-05 * DAYS_PER_YEAR},
   2.85885980666130812e-04 * SOLAR_MASS},
  {{1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01},
   0.,
   {2.96460137564761618e-03 * DAYS_PER_YEAR,
    2.37847173959480950e-03 * DAYS_PER_YEAR,
    -2.96589568540237556e-05 * DAYS_PER_YEAR},
   4.36624404335156298e-05 * SOLAR_MASS},
  {{1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01},
   0.,
   {2.68067772490389322e-03 * DAYS_PER_YEAR,
    1.62824170038242295e-03 * DAYS_PER_YEAR,
    -9.51592254519715870e-05 * DAYS_PER_YEAR},
   5.15138902046611451e-05 * SOLAR_MASS}
};

static const int BODIES_SIZE =
  sizeof (solar_bodies) / sizeof (solar_bodies[0]);

static void
offset_momentum (struct nbody_body *bodies, unsigned int nbodies)
{
  unsigned int i, k;

  for (i = 0; i < nbodies; ++i)
    for (k = 0; k < 3; ++k)
      bodies[0].v[k] -= bodies[i].v[k] * bodies[i].mass / SOLAR_MASS;
}

static double
bodies_energy (struct nbody_body *bodies, unsigned int nbodies)
{
  double dx[3], distance, e = 0.0;
  unsigned int i, j, k;

  for (i = 0; i < nbodies; ++i)
    {
      e += bodies[i].mass * (bodies[i].v[0] * bodies[i].v[0]
                             + bodies[i].v[1] * bodies[i].v[1]
                             + bodies[i].v[2] * bodies[i].v[2]) / 2.;

      for (j = i + 1; j < nbodies; ++j)
        {
          for (k = 0; k < 3; ++k)
            dx[k] = bodies[i].x[k] - bodies[j].x[k];

          distance = sqrt (dx[0] * dx[0] + dx[1] * dx[1] + dx[2] * dx[2]);
          e -= (bodies[i].mass * bodies[j].mass) / distance;
        }
    }

  return e;
}

static int
nbody_benchmark_body (int rpt)
{
  int j;
  double tot_e = 0.0;

  for (j = 0; j < rpt; j++)
    {
      int i;

      offset_momentum (solar_bodies, BODIES_SIZE);
      tot_e = 0.0;
      for (i = 0; i < 100; ++i)
        tot_e += bodies_energy (solar_bodies, BODIES_SIZE);
    }

  return double_eq_beebs (tot_e, -16.907516382852478);
}

static int
verify_nbody_benchmark (int tot_e_ok)
{
  int i, j;
  static struct nbody_body expected[] = {
    {{0, 0, 0}, 0.,
     {-0.000387663407198742665776131088862,
      -0.0032753590371765706722173572274,
      2.39357340800030020670947916717e-05},
     39.4784176043574319692197605036},
    {{4.84143144246472090230781759601, -1.16032004402742838777840006514,
      -0.103622044471123109232735259866},
     0.,
     {0.606326392995832019749968821998, 2.81198684491626016423992950877,
      -0.0252183616598876288172892401462},
     0.0376936748703894930478952574049},
    {{8.34336671824457987156620220048, 4.1247985641243047894022311084,
      -0.403523417114321381049535375496},
     0.,
     {-1.01077434617879236000703713216, 1.82566237123041186229954746523,
      0.00841576137658415351916474378413},
     0.0112863261319687668143840753032},
    {{12.8943695621391309913406075793, -15.1111514016986312469725817209,
      -0.223307578892655733682204299839},
     0.,
     {1.08279100644153536414648897335, 0.868713018169608219842814378353,
      -0.0108326374013636358983880825235},
     0.0017237240570597111687795033319},
    {{15.3796971148509165061568637611, -25.9193146099879641042207367718,
      0.179258772950371181309492385481},
     0.,
     {0.979090732243897976516677772452, 0.594698998647676169149178804219,
      -0.0347559555040781037460462243871},
     0.00203368686992463042206846779436}
  };

  if (!tot_e_ok)
    return 0;

  for (i = 0; i < BODIES_SIZE; i++)
    {
      for (j = 0; j < 3; j++)
        {
          if (double_neq_beebs (solar_bodies[i].x[j], expected[i].x[j]))
            return 0;
          if (double_neq_beebs (solar_bodies[i].v[j], expected[i].v[j]))
            return 0;
        }
      if (double_neq_beebs (solar_bodies[i].mass, expected[i].mass))
        return 0;
    }

  return 1;
}

void
run_nbody_benchmark (void)
{
  uint64_t start_cycles;
  uint64_t stop_cycles;
  int res;

  nbody_benchmark_body (1);

  start_cycles = embench_read_mcycle64 ();
  res = nbody_benchmark_body (NBODY_LOCAL_SCALE_FACTOR * CPU_MHZ);
  stop_cycles = embench_read_mcycle64 ();

  embench_report_result ("Nbody", verify_nbody_benchmark (res),
                         stop_cycles - start_cycles);
}
