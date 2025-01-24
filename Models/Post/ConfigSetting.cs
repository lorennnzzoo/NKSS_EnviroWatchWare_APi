using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Post
{
    public class ConfigSetting
    {
        public string GroupName { get; set; }
        public string ContentName { get; set; }
        public string ContentValue { get; set; }
        public bool Active { get; set; } = true;
    }
}
