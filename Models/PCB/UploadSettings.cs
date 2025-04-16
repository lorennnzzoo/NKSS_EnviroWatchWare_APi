using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.PCB
{
    public class UploadSettings
    {
        public string LiveUrl { get; set; }
        public string DelayUrl { get; set; }
        public int LiveInterval { get; set; }
        public int DelayInterval { get; set; }
        public int LiveRecords { get; set; }
        public int DelayRecords { get; set; }
    }
}
