using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models
{
    public class ConfigSetting
    {
        public int Id { get; set; } 
        public string GroupName { get; set; } 
        public string ContentName { get; set; } 
        public string ContentValue { get; set; } 
        public bool Active { get; set; } = true;
    }

}
