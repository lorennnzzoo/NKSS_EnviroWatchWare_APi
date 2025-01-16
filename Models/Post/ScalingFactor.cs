using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Post
{
    public class ScalingFactor
    {
        public double? MinInput { get; set; } 

        public double? MaxInput { get; set; } 

        public double? MinOutput { get; set; }  

        public double? MaxOutput { get; set; }

        public bool Active { get; set; } = true;
    }

}
