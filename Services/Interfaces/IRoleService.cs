using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface IRoleService
    {
        IEnumerable<Models.Role> GetAllRoles();
        Models.Role GetRoleById(int id);

        void CreateAdminRole();
    }
}
