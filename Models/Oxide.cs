using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models
{
    public class Oxide
    {
        public int? Id { get; set; }
        public string OxideName { get; set; }
        public string Limit { get; set; }
        public bool Active { get; set; }
    }

}
