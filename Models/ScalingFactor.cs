using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models
{
    public class ScalingFactor
    {
        public int? Id { get; set; }  
        public double MinInput { get; set; } 

        public double MaxInput { get; set; } 

        public double MinOutput { get; set; }  

        public double MaxOutput { get; set; }

        public bool Active { get; set; } 
    }

}
