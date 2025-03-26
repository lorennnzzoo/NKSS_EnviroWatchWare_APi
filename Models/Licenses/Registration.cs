using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Licenses
{
    public class Registration
    {
        public int CompanyId { get; set; }
        public string Email { get; set; }
        public string Phone { get; set; }
        public string Address { get; set; }
        public string State { get; set; }
        public string Country { get; set; }
        public DateTime? ExpiresAt { get; set; }
    }

    public class SoftrackLicenseResponse
    {
        public string Key { get; set; }
    }
}
