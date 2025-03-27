using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Licenses
{
    public class License
    {
        public string LicenseType { get; set; }
        public string LicenseKey { get; set; }
        public bool Active { get; set; }
    }
    public class LicenseResponse
    {
        public string LicenseType { get; set; }
        public string LicenseKey { get; set; }
        public bool Valid { get; set; }
    }
}
