using Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize(Roles = "Admin,Customer,Demo")]
    [RoutePrefix("User")]
    public class UserController : ApiController
    {
        private readonly UserService user_service;
        private readonly Helpers.Validator validator = new Helpers.Validator();
        public UserController(UserService _user_service)
        {
            this.user_service = _user_service;
        }
        [HttpGet]
        [Route("GetAllUsers")]
        public IHttpActionResult GetAllUsers()
        {
            try
            {
                var username = User.Identity.Name;
                var users = user_service.GetAllUsers(username);
                //if (users.Count() > 0)
                //{
                    return Ok(users);
                //}
                //return NotFound();
            }
            catch (Exception ex)
            {
                HttpResponseMessage response = new HttpResponseMessage();

                response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("ActivateUser")]
        public IHttpActionResult Activate(Guid id)
        {
            try
            {
                //var username = User.Identity.Name;
                user_service.ActivateUser(id);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpDelete]
        [Route("DeleteUser")]
        public IHttpActionResult Delete(Guid id)
        {
            try
            {
                var username = User.Identity.Name;
                user_service.DeleteUser(id, username);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }


        [HttpGet]
        [Route("GetUserProfile")]
        public IHttpActionResult GetUserProfile()
        {
            try
            {
                var username = User.Identity.Name;
                var user = user_service.GetUserProfile(username);
                return Ok(user);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }
    }
}
