#include "TreeData.h"
using namespace std;

EventData::EventData()
  : run_id   (0)
  , spill_id (0)
  , event_id (0)
  , fpga_bits(0)
  , nim_bits (0)
{
  ;
}

HitData::HitData() 
  : det_id    (0)
  , ele_id    (0)
  , tdc_time  (0)
  , drift_dist(0)
{
  ;
}